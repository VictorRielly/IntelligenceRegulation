#!/usr/bin/env python3
"""Lane B5: the pg+rot calibration ported to Llama-3-8B (NousResearch/Meta-Llama-3-8B
rev 315b2009..., width 4096, FFN 14336, 32 q / 8 kv heads, head_dim 128, 32 layers,
RoPE theta 500000, eps 1e-5, vocab 128256, BF16).

Reuses the B3/B4 machinery from results/zk60_1b_calibration_20260929 with
ZK60_MODEL=llama3-8b (geometry, shard pins, AO window 0..8, float32 weight
transforms, column-blocked exact int matmuls). New here: a pluggable tokenizer
(the Llama-3 tokenizer.json via `tokenizers`, or an explicitly labelled
SYNTHETIC plumbing input with no fidelity meaning), row-block embedding gather,
a vocabulary-streamed head (the 128256 x 4096 head never materialises in
float32), and a lean pass 2 (held-out chained on all sequences, isolated on a
subset). One layer resident at a time. Calibration data, not a proof.
"""

from __future__ import annotations

import os

os.environ.setdefault("ZK60_MODEL", "llama3-8b")
for _k in ("OPENBLAS_NUM_THREADS", "OMP_NUM_THREADS", "MKL_NUM_THREADS"):
    os.environ.setdefault(_k, os.environ.get("B5_THREADS", "4"))

import argparse  # noqa: E402
import hashlib  # noqa: E402
import json  # noqa: E402
import sys  # noqa: E402
import time  # noqa: E402
from pathlib import Path  # noqa: E402

LANE1B = Path("/home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929")
sys.path.insert(0, str(LANE1B))
import numpy as np  # noqa: E402

import tlcalib as tc  # noqa: E402
import b3calib as b3  # noqa: E402
import b3_ladder as bl  # noqa: E402
import corpus as c3  # noqa: E402
import corpus4  # noqa: E402

assert tc.MODEL_NAME == "llama3-8b" and tc.GEO.d == 4096
HERE = Path(__file__).resolve().parent
MODEL = {"repo": "NousResearch/Meta-Llama-3-8B", "name": "Llama-3-8B (Meta Llama 3)",
         "revision": "315b20096dc791d381d514deb5f8bd9c8d6d3061", "shards_sha256": tc.MODEL_SHARDS,
         "licence": "Meta Llama 3 Community License: LICENSE (sha256 475211637354ce4c...) and USE_POLICY.md "
                    "(sha256 003513f595a20b7d...) from the pinned revision, copied into each export with NOTICE"}
SCHEMA = bl.SCHEMA
BOS = 128000
log = bl.log


# ------------------------------------------------------------------ tokenizer / corpus

class HFTokenizer:
    def __init__(self, path: Path):
        from tokenizers import Tokenizer
        self.path = path
        self.sha256 = hashlib.sha256(path.read_bytes()).hexdigest()
        self.tk = Tokenizer.from_file(str(path))

    def encode(self, text: str, bos: bool = False):
        ids = self.tk.encode(text, add_special_tokens=False).ids
        return ([BOS] if bos else []) + ids


def text_sequences(tok, which: str, T: int, per: int):
    """corpus.py's licence/docstring windows, with the Llama-3 tokenizer and BOS."""
    files, mods = (c3.CALIB_FILES, c3.CALIB_MODULES) if which == "calib" else (c3.HELDOUT_FILES, c3.HELDOUT_MODULES)
    seqs, meta = [], []
    for name, text in c3._texts(files, mods):
        ids = tok.encode(text)
        body = T - 1
        n = min(per, len(ids) // body)
        stride = max(body, (len(ids) - body) // max(1, n))
        for k in range(n):
            chunk = [BOS] + ids[k * stride:k * stride + body]
            if len(chunk) == T:
                seqs.append(chunk)
                meta.append({"source": name, "domain": "licence-docstring", "offset": k * stride,
                             "sha256": hashlib.sha256(",".join(map(str, chunk)).encode()).hexdigest()[:16]})
    return seqs, meta


def fineweb_sequences(tok, which: str, T: int, n: int):
    import pyarrow.parquet as pq
    tab = pq.ParquetFile(corpus4.PARQUET).read_row_group(corpus4.ROW_GROUP[which], columns=["text", "id", "url"]).to_pydict()
    seqs, meta = [], []
    for row, (text, did, url) in enumerate(zip(tab["text"], tab["id"], tab["url"])):
        if len(seqs) >= n:
            break
        ids = tok.encode(text[:8 * T + 2000])
        if len(ids) < T - 1 + 8:
            continue
        chunk = [BOS] + ids[:T - 1]
        seqs.append(chunk)
        meta.append({"source": "fineweb-edu", "domain": "fineweb-edu", "doc_id": did, "url": url, "row_group": corpus4.ROW_GROUP[which],
                     "row": row, "sha256": hashlib.sha256(",".join(map(str, chunk)).encode()).hexdigest()[:16]})
    return seqs, meta


def synthetic_sequences(which: str, T: int, n: int):
    """PLUMBING ONLY: BOS + seeded uniform token ids. No fidelity meaning."""
    rng = np.random.default_rng(11 if which == "calib" else 12)
    seqs = [[BOS] + rng.integers(1000, 120000, T - 1).tolist() for _ in range(n)]
    return seqs, [{"source": "synthetic", "domain": "synthetic"} for _ in seqs]


# ------------------------------------------------------------------ embedding / head (streamed)

def bf16_rows(raw: np.ndarray, rows, d: int) -> np.ndarray:
    u = raw.reshape(-1, d)[np.asarray(rows)].astype(np.uint32) << 16
    return u.view(np.float32)


class Head:
    """Final RMSNorm + LM head with the head streamed in vocab blocks of bf16."""

    def __init__(self, ck, block: int = 8192):
        ref = ck.refs["lm_head.weight"]
        self.raw = np.frombuffer(ref.read_bytes(max_bytes=ref.end - ref.start), dtype="<u2").reshape(ref.shape)
        self.norm = tc.tensor_f32(ck.refs["model.norm.weight"])
        self.block = block
        self.V = ref.shape[0]

    def hidden(self, x):
        return tc.f_xhat(x.astype(np.float32), tc.GEO.eps) * self.norm

    def blocks(self, h):
        for v0 in range(0, self.V, self.block):
            w = (self.raw[v0:v0 + self.block].astype(np.uint32) << 16).view(np.float32)
            yield v0, (h @ w.T).astype(np.float64)

    def metrics(self, xf, xi, ids, mask=None, group=4):
        """top-1 agreement, ppl float/int, mean KL(float || int) over next-token
        positions, two streamed passes per group (max/logsumexp, then KL)."""
        if mask is not None:
            xf, xi, ids = xf[mask], xi[mask], ids[mask]
        if len(ids) == 0:
            return None
        agree = n = 0
        nll_f = nll_i = kl = 0.0
        for s in range(0, len(ids), group):
            hf = self.hidden(xf[s:s + group])[:, :-1].reshape(-1, tc.GEO.d)
            hi = self.hidden(xi[s:s + group])[:, :-1].reshape(-1, tc.GEO.d)
            tgt = ids[s:s + group, 1:].reshape(-1)
            R = hf.shape[0]
            mf = np.full(R, -np.inf); mi = np.full(R, -np.inf)
            af = np.zeros(R, dtype=np.int64); ai = np.zeros(R, dtype=np.int64)
            tf = np.zeros(R); ti = np.zeros(R)
            # pass 1: maxima, argmax, target logits
            lfs, lis = [], []
            for (v0, lf), (_, li) in zip(self.blocks(hf), self.blocks(hi)):
                bf, bi = lf.max(1), li.max(1)
                upd_f, upd_i = bf > mf, bi > mi
                af = np.where(upd_f, v0 + lf.argmax(1), af); ai = np.where(upd_i, v0 + li.argmax(1), ai)
                mf, mi = np.maximum(mf, bf), np.maximum(mi, bi)
                inb = (tgt >= v0) & (tgt < v0 + lf.shape[1])
                tf[inb] = lf[inb, tgt[inb] - v0]; ti[inb] = li[inb, tgt[inb] - v0]
            sf = np.zeros(R); si = np.zeros(R)
            for (v0, lf), (_, li) in zip(self.blocks(hf), self.blocks(hi)):
                sf += np.exp(lf - mf[:, None]).sum(1); si += np.exp(li - mi[:, None]).sum(1)
            lsef, lsei = mf + np.log(sf), mi + np.log(si)
            for (v0, lf), (_, li) in zip(self.blocks(hf), self.blocks(hi)):
                pf = lf - lsef[:, None]
                kl += float((np.exp(pf) * (pf - (li - lsei[:, None]))).sum())
            agree += int((af == ai).sum()); n += R
            nll_f -= float((tf - lsef).sum()); nll_i -= float((ti - lsei).sum())
        return {"sequences": int(len(ids)), "positions": n, "top1_agreement": agree / n, "ppl_float": float(np.exp(nll_f / n)),
                "ppl_int": float(np.exp(nll_i / n)), "kl_float_to_int_mean": kl / n}


# ------------------------------------------------------------------ main

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--variant", default="pg")
    ap.add_argument("--rotate", type=int, default=1)
    ap.add_argument("--T", type=int, default=32)
    ap.add_argument("--calib-T", type=int, default=None)
    ap.add_argument("--tokenizer", default=None, help="path to the Llama-3 tokenizer.json")
    ap.add_argument("--synthetic", action="store_true", help="PLUMBING ONLY: seeded random token ids, no fidelity meaning")
    ap.add_argument("--calib-per", type=int, default=3)
    ap.add_argument("--heldout-per", type=int, default=4)
    ap.add_argument("--fw-calib", type=int, default=27)
    ap.add_argument("--fw-heldout", type=int, default=36)
    ap.add_argument("--iso-seqs", type=int, default=12)
    ap.add_argument("--site-seqs", type=int, default=3)
    ap.add_argument("--chunk", type=int, default=8)
    ap.add_argument("--layers", type=int, default=None)
    ap.add_argument("--tag", default="")
    ap.add_argument("--export", action="store_true")
    ap.add_argument("--export-seqs", type=int, default=2)
    args = ap.parse_args()
    T, T_cal = args.T, args.calib_T or args.T
    tool_sha = {p: bl.sha_file(LANE1B / p) for p in ("tlcalib.py", "b3calib.py", "b3_ladder.py", "corpus.py", "corpus4.py")}
    tool_sha["b5_8b.py"] = bl.sha_file(Path(__file__))
    v0 = b3.variant_by_name(args.variant, rotate=args.rotate)
    kw = dict(v0.__dict__)
    kw.update(tn=9, cn_max=1 << 20)       # D24: tn <= 9 at width 4096, Cn <= 2^20
    var = b3.Variant(**kw)
    name = f"llama3_8b_{args.variant.replace('+', '_')}_rot{args.rotate}" + (f"_{args.tag}" if args.tag else "") \
        + ("_SYNTHETIC" if args.synthetic else "") + f"_T{T}" + (f"_cal{T_cal}" if T_cal != T else "")
    if args.layers:
        name += f"_L{args.layers}smoke"
    out = HERE / "runs" / name
    out.mkdir(parents=True, exist_ok=True)
    t0 = time.time()
    log(f"B5 {name}: {vars(args)}; {var}; threads {os.environ.get('OPENBLAS_NUM_THREADS')}")
    log(f"exact-mm selfcheck {tc.selfcheck_exact_mm()}; native table pins {b3.verify_tables()['all_pins_ok']}")
    ck = tc.open_checkpoint()
    L = args.layers or ck.config["layers"]
    log(f"checkpoint pinned ({time.time() - t0:.0f}s): {ck.identity['shard_sha256']}")
    if args.synthetic:
        cal, cal_meta = synthetic_sequences("calib", T_cal, 24)
        ho, ho_meta = synthetic_sequences("heldout", T, 12)
        tokinfo = {"kind": "SYNTHETIC (plumbing only)"}
    else:
        if not args.tokenizer:
            raise SystemExit("no Llama-3 tokenizer: pass --tokenizer <tokenizer.json> (none is available offline) or --synthetic")
        tok = HFTokenizer(Path(args.tokenizer))
        tokinfo = {"kind": "tokenizers BPE tokenizer.json", "path": str(tok.path), "sha256": tok.sha256, "bos": BOS}
        cal, cal_meta = text_sequences(tok, "calib", T_cal, args.calib_per)
        ho, ho_meta = text_sequences(tok, "heldout", T, args.heldout_per)
        c2, m2 = fineweb_sequences(tok, "calib", T_cal, args.fw_calib)
        h2, n2 = fineweb_sequences(tok, "heldout", T, args.fw_heldout)
        cal, cal_meta, ho, ho_meta = cal + c2, cal_meta + m2, ho + h2, ho_meta + n2
    domains = np.array([m["domain"] for m in ho_meta])
    cal_ids, ho_ids = np.array(cal, dtype=np.int64), np.array(ho, dtype=np.int64)
    log(f"tokenizer {tokinfo}; calib {cal_ids.shape} held-out {ho_ids.shape} domains {dict(zip(*np.unique(domains, return_counts=True)))}")
    R = b3.Rotation(tc.GEO.d, args.rotate)
    eref = ck.refs["model.embed_tokens.weight"]
    eraw = np.frombuffer(eref.read_bytes(max_bytes=eref.end - eref.start), dtype="<u2")
    xc_f = bf16_rows(eraw, cal_ids.reshape(-1), tc.GEO.d).reshape(*cal_ids.shape, -1)
    xh_f = bf16_rows(eraw, ho_ids.reshape(-1), tc.GEO.d).reshape(*ho_ids.shape, -1)
    del eraw
    xc_f = R.fwd(xc_f.reshape(-1, tc.GEO.d)).astype(np.float32).reshape(xc_f.shape)
    xh_f = R.fwd(xh_f.reshape(-1, tc.GEO.d)).astype(np.float32).reshape(xh_f.shape)
    rope_f, rope_fc = tc.rope_f32(T), tc.rope_f32(T_cal)
    rope_i = b3.rope_generate(T, tc.GEO.dh, tc.GEO.theta, b3.F_RO)

    stats = bl.float_stats(ck, xc_f, rope_fc, L, R, HERE / "runs" / (f"b5_stats_T{T_cal}_n{len(cal_ids)}_r{args.rotate}"
                                                                        + ("_SYN" if args.synthetic else "") + f"_L{L}.pkl"),
                           chunk=args.chunk)
    log(f"pass 1 done ({time.time() - t0:.0f}s)")
    glob, caches, ptable = bl.prepass(ck, stats, var, R, L, "none")
    prof = {"cn_a": glob.cn_a, "cn_m": glob.cn_m, "e_s": glob.e_s, "silu": glob.silu, "shifts": glob.shifts,
            "s_in": glob.s_in, "s_out": glob.s_out}
    log(f"profile decisions: cn {glob.cn_a}/{glob.cn_m} shifts {glob.shifts} s_x {glob.s_in[0]:.4g}")
    (out / "prepass.json").write_text(tc.jdump({"variant": var.__dict__, "profile": prof, "layers": ptable}))

    # ---------------- pass 2 (lean)
    rec_h = tc.Rec(len(ho_ids))
    xi_h = tc.quantize_input(xh_f, glob.s_in[0], rec_h)
    ref_h = np.array([f is not None for f in rec_h.first])
    first_h = [("input", f) if f else None for f in rec_h.first]
    chain_dir = out / "chain_int16"          # per-layer integer residuals spilled to disk (memory)
    chain_dir.mkdir(exist_ok=True)
    np.save(chain_dir / "x_L00.npy", xi_h.astype(np.int16))
    xf_h = xh_f
    layers = []
    exp_root = HERE / "export" / name
    iso = slice(0, min(args.iso_seqs, len(ho_ids)))
    for l in range(L):
        tl = time.time()
        W = bl.load_layer(ck, l, R)
        P, rep = b3.solve_layer(W, stats[l], var, glob.s_in[l], glob.s_out[l], glob, caches[l])
        xf_next = np.concatenate([tc.f_block(xf_h[s:s + args.chunk], W, *rope_f) for s in range(0, len(ho_ids), args.chunk)])
        rh, ri = tc.Rec(len(ho_ids)), tc.Rec(iso.stop)
        xi_next = bl.run_int(xi_h, P, rope_i, rh, args.chunk)
        xq = tc.quantize_input(xf_h[iso], glob.s_in[l], ri)
        xiso = bl.run_int(xq, P, rope_i, ri, args.chunk)
        site = b3.site_errors(xq[:args.site_seqs], P, rope_i, W, rope_f)
        del W
        s_ = glob.s_in[l]
        iso_cos = tc.cos_rows(xiso * s_, xf_next[iso])
        iso_dcos = tc.cos_rows(xiso * s_ - xq * s_, xf_next[iso] - xf_h[iso])
        ch_cos = tc.cos_rows(xi_next * s_, xf_next)
        for i, f in enumerate(rh.first):
            if f is not None and first_h[i] is None:
                first_h[i] = (l, f)
        ref_h |= np.array([f is not None for f in rh.first])
        entry = {"layer": l, "constants": bl.layer_constants(P, var), "solve": rep,
                 "isolated": {"sequences": iso.stop, "cos": bl.summ(iso_cos), "delta_cos": bl.summ(iso_dcos), "range": ri.summary()},
                 "chained": {"cos": bl.summ(ch_cos), "range": rh.summary()}, "site_rel_error_isolated": site,
                 "massive": {"float_absmax": float(np.abs(xf_next).max()), "float_absmax_p0": float(np.abs(xf_next[:, 0]).max()),
                             "float_absmax_rest": float(np.abs(xf_next[:, 1:]).max())}}
        if args.export:
            bl.export_layer(exp_root, l, P, rep, T, var)
            entry["export_manifest_sha256"] = bl.sha_file(exp_root / f"layer_{l:02d}" / "manifest.json")
        layers.append(entry)
        (out / f"layer_{l:02d}.json").write_text(tc.jdump(entry))
        nv = lambda r: sum(s["violations"] for s in r.summary()["sites"].values())
        clip = {k: v for k, v in rep.get("weights_clipped", {}).items() if v}
        log(f"L{l:02d} e_s {P.e_s} silu {P.silu} | iso cos {iso_cos.mean():.5f} dcos {iso_dcos.mean():.4f} | chain cos {ch_cos.mean():.5f} | "
            f"viol iso {nv(ri)} chain {nv(rh)} | refused {int(ref_h.sum())} | clip {clip} | float absmax {entry['massive']['float_absmax']:.1f} "
            f"(p0 {entry['massive']['float_absmax_p0']:.1f}) ({time.time() - tl:.0f}s)")
        log("    site rel err: " + " ".join(f"{k} {v:.3f}" for k, v in site.items() if k != "refused_sequences"))
        xf_h, xi_h = xf_next, xi_next
        np.save(chain_dir / f"x_L{l + 1:02d}.npy", xi_h.astype(np.int16))

    summary = {"variant": name, "variant_options": var.__dict__, "model": MODEL, "tokenizer": tokinfo, "args": vars(args),
               "checkpoint_identity": {k: ck.identity[k] for k in ("schema", "config_sha256", "shard_sha256", "tensor_count")},
               "calib_sequences": cal_meta, "heldout_sequences": ho_meta, "profile": prof, "heldout_refused": int(ref_h.sum()),
               "heldout_first_refusal": [None if f is None else {"layer": f[0], "site": f[1]} for f in first_h],
               "calibration": {"T_cal": T_cal, "sequences": len(cal_ids)}, "tool_sha256": tool_sha}
    if L == ck.config["layers"]:
        head = Head(ck)
        xf_fin = R.inv(xf_h).astype(np.float32)
        xi_fin = R.inv(xi_h * glob.s_out[-1]).astype(np.float32)
        acc = ~ref_h
        summary["head_all_diagnostic"] = head.metrics(xf_fin, xi_fin, ho_ids)
        summary["head_accepted"] = head.metrics(xf_fin, xi_fin, ho_ids, mask=acc)
        summary["by_domain"] = {}
        for dom in sorted(set(domains.tolist())):
            dm = domains == dom
            summary["by_domain"][dom] = {"sequences": int(dm.sum()), "refused": int((ref_h & dm).sum()),
                                         "head_all_diagnostic": head.metrics(xf_fin, xi_fin, ho_ids, mask=dm),
                                         "head_accepted": head.metrics(xf_fin, xi_fin, ho_ids, mask=dm & acc)}
            log(f"domain {dom}: {summary['by_domain'][dom]}")
        log(f"head (all, refusals clamped = diagnostic): {summary['head_all_diagnostic']}")
    if args.export and L == ck.config["layers"]:
        doms = list(dict.fromkeys(domains.tolist()))
        firsts = [next((i for i in range(len(ho_ids)) if not ref_h[i] and domains[i] == dm), None) for dm in doms]
        ok = [i for i in firsts if i is not None]
        ok += [i for i in range(len(ho_ids)) if not ref_h[i] and i not in ok]
        ok = sorted(ok[:args.export_seqs])
        seqs = []
        for i in ok:
            sd = exp_root / f"seq_ho{i:02d}"
            sd.mkdir(parents=True, exist_ok=True)
            files = {}
            for l in range(L):
                xin = np.load(chain_dir / f"x_L{l:02d}.npy", mmap_mode="r")[i]
                xout = np.load(chain_dir / f"x_L{l + 1:02d}.npy", mmap_mode="r")[i]
                files[f"x_in_L{l:02d}"] = bl.write_bin(sd, f"x_in_L{l:02d}", xin, "<i2")
                files[f"x_out_L{l:02d}"] = bl.write_bin(sd, f"x_out_L{l:02d}", xout, "<i2")
            (sd / "manifest.json").write_text(json.dumps({
                "schema": SCHEMA, "kind": "sequence", "id": f"ho{i:02d}", "heldout_index": i, "source": ho_meta[i],
                "token_ids": ho_ids[i].tolist(), "T": T, "accepted_at_every_layer": True,
                "selection": "the first held-out sequence accepted at every layer in each held-out domain (no fidelity-based choice)",
                "basis": f"rotated residual x' = x R^T (randomized Hadamard n = 4096, seed {args.rotate})",
                "residual_scales_in_out": [[glob.s_in[l], glob.s_out[l]] for l in range(L)], "arrays": files}, indent=1, sort_keys=True))
            seqs.append(sd.name)
        pc = layers[0]["constants"]
        uniform = {k: pc[k] if all(e["constants"][k] == pc[k] for e in layers) else None for k in pc}
        raw = R.sign.astype("<f8").tobytes()
        (exp_root / "rotation_sign.bin").write_bytes(raw)
        (exp_root / "rotation.json").write_text(json.dumps({"kind": "randomized Sylvester Hadamard", "n": tc.GEO.d, "seed": args.rotate,
                                                            "file": {"name": "rotation_sign.bin", "dtype": "float64 little-endian",
                                                                     "shape": [tc.GEO.d], "sha256": hashlib.sha256(raw).hexdigest()},
                                                            "definition": "R = H diag(sign) / sqrt(4096); x' = x R^T"}, indent=1))
        profile = {"schema": SCHEMA, "kind": "profile", "variant": name, "variant_options": var.__dict__, "model": MODEL,
                   "calibration_tool": {"path": "results/zk60_1b_calibration_20260929 + results/zk60_8b_calibration_20261017",
                                        "sha256": tool_sha},
                   "T": T, "profile_constants": uniform,
                   "per_layer_constants_differ": sorted(k for k, v in uniform.items() if v is None),
                   "layers": [{"layer": l, "dir": f"layer_{l:02d}", "manifest_sha256": layers[l]["export_manifest_sha256"]} for l in range(L)],
                   "sequences": seqs,
                   "metadata_out_of_proof": {
                       "geometry": {"width": tc.GEO.d, "hidden": tc.GEO.f, "q_heads": tc.GEO.H, "kv_heads": tc.GEO.KV,
                                    "head_dim": tc.GEO.dh, "layers": L, "rope_theta": tc.GEO.theta, "rms_norm_eps": tc.GEO.eps},
                       "residual_scale_s_x": glob.s_in[0], "residual_scales_in": glob.s_in, "residual_scales_out": glob.s_out,
                       "rotation": {"kind": "randomized Sylvester Hadamard R = H diag(sign)/sqrt(4096)", "seed": args.rotate,
                                    "sign_sha256": hashlib.sha256(raw).hexdigest(),
                                    "embedding": "x' = x R^T before layer 0", "head": "x = x' R before the final norm"},
                       "rope_tables": "generated with hashline tables_attn.rs rope_tables_generate semantics at base 500000.0 "
                                      "(the 8B profile's own value; the accepted TinyLlama class pins 10000)",
                       "tokenizer": tokinfo,
                       "per_layer": [{"layer": e["layer"], "scales": e["solve"]["metadata_scales"]} for e in layers],
                       "calibration": {"T_cal": T_cal, "calibration_sequences": len(cal_ids),
                                       "domains": sorted(set(m["domain"] for m in cal_meta))}},
                   "fidelity_T": {"heldout_accepted": summary.get("head_accepted"), "heldout_refused": int(ref_h.sum()),
                                  "heldout_sequences": len(ho_ids), "calibration_sequences": len(cal_ids)},
                   "scope": "calibration data, not a proof, not a privacy claim"}
        (exp_root / "profile.json").write_text(json.dumps(profile, indent=1, sort_keys=True))
        # licence obligations travel with derived weights: the repo's LICENSE / USE_POLICY.md and the NOTICE
        for f in ("LICENSE", "USE_POLICY.md"):
            (exp_root / f).write_bytes((tc.MODEL_DIR / f).read_bytes())
        (exp_root / "NOTICE").write_bytes((HERE / "NOTICE").read_bytes())
        summary["export"] = {"root": str(exp_root), "profile_sha256": bl.sha_file(exp_root / "profile.json"), "sequences": seqs}
        log(f"export written: {exp_root} profile sha256 {summary['export']['profile_sha256']}")
    summary["seconds"] = time.time() - t0
    (out / "summary.json").write_text(tc.jdump(summary))
    log(f"done ({time.time() - t0:.0f}s) -> {out}")


if __name__ == "__main__":
    try:
        from threadpoolctl import threadpool_limits
        with threadpool_limits(limits=int(os.environ.get("B5_THREADS", "4"))):
            main()
    except ImportError:
        main()
