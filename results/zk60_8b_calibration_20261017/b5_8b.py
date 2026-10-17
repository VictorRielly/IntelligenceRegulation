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


# ------------------------------------------------------------------ B6 helpers

WORDS = ("wq", "wk", "wv", "wo", "gamma_a", "gamma_m", "wg_t", "wu_t", "wd_t", "exp", "act")
DTY = {"wq": "<i1", "wk": "<i1", "wv": "<i1", "wo": "<i1", "gamma_a": "<i1", "gamma_m": "<i1", "wg_t": "<i1",
       "wu_t": "<i1", "wd_t": "<i1", "exp": "<i8", "act": "<i2"}


def word_sha(P, name):
    return hashlib.sha256(np.ascontiguousarray(getattr(P, name)).astype(DTY[name]).tobytes()).hexdigest()


def glob_from_prepass(path: Path, tn: int):
    pr = json.loads(path.read_text())["profile"]
    return b3.Globals(s_in=pr["s_in"], s_out=pr["s_out"], cn_a=pr["cn_a"], cn_m=pr["cn_m"],
                      K_a=b3.norm_K(pr["cn_a"], tn) if pr["cn_a"] else None, K_m=b3.norm_K(pr["cn_m"], tn) if pr["cn_m"] else None,
                      e_s=pr["e_s"], silu=tuple(pr["silu"]) if pr["silu"] else None, shifts=pr["shifts"])


def link_identical(ref_dir: Path, tgt_dir: Path) -> int:
    """hard-link every file of tgt_dir whose bytes equal ref_dir's file of the same name (export/FORMAT_CHANGES.md)."""
    n = 0
    for q in sorted(tgt_dir.iterdir()):
        r = ref_dir / q.name
        if q.is_file() and not q.is_symlink() and r.is_file() and not r.is_symlink() and q.stat().st_size == r.stat().st_size \
                and os.stat(q).st_ino != os.stat(r).st_ino and bl.sha_file(q) == bl.sha_file(r):
            tmp = q.with_name(q.name + ".linktmp")
            os.link(r, tmp)
            os.replace(tmp, q)
            n += 1
    return n


def perhead_qk(W, st, var, P, rep, raw_h):
    """B6 experiment (NOT native): one score scale / exp table PER QUERY HEAD.
    K at its lower bound per (kv, pair); each head h takes the smallest
    P_h = 2^(e_s,h - SH_S) its own Q rows and score range allow; the exp lookup
    then needs a table per head."""
    g, m = tc.GEO, var.m
    sh = rep["shifts"]
    K_a = rep["norm_consts"]["K_a"]
    ga = W["input_layernorm.weight"].astype(np.float64)
    fold_a = ga * K_a / P.gamma_a.astype(np.float64)
    Wq_e = W["self_attn.q_proj.weight"].astype(b3.WDT) * fold_a[None, :].astype(b3.WDT)
    Wk_e = W["self_attn.k_proj.weight"].astype(b3.WDT) * fold_a[None, :].astype(b3.WDT)
    s2 = 2.0 ** sh["qkv"]
    Lq = np.maximum(b3.rb(st["q_pair"], m, var.margin_ch) / 127.0, s2 * b3._pairmax(np.abs(Wq_e).max(1), g.H) / 127.0)   # (H, half)
    Lk = np.maximum(b3.rb(st["k_pair"], m, var.margin_ch) / 127.0, s2 * b3._pairmax(np.abs(Wk_e).max(1), g.KV) / 127.0)  # (KV, half)
    Lk_h = np.repeat(Lk, g.G, axis=0)
    need = (Lq * Lk_h).max(1)
    e_rng = np.ceil(np.log2(raw_h * var.m2 / 127.0) - 1e-9).astype(int)
    e_h = np.maximum(e_rng, np.ceil(np.log2(need) + sh["s"] - 1e-9).astype(int))
    Ph = 2.0 ** (e_h - sh["s"])
    # K is shared by the G query heads of a group: s_k in [Lk, U], U = min_h P_h / Lq(h, c); geometric middle
    U = (Ph[:, None] / Lq).reshape(g.KV, g.G, g.half).min(1)
    s_k = np.sqrt(Lk * U)
    s_q = Ph[:, None] / np.repeat(s_k, g.G, axis=0)                                            # (H, half) >= Lq
    q_rows = np.concatenate([s_q, s_q], 1).reshape(-1)
    k_rows = b3.k_rows(s_k)
    P.wq = b3.qw_rows(Wq_e, q_rows / s2, rep, "wq")
    P.wk = b3.qw_rows(Wk_e, k_rows / s2, rep, "wk")
    P.exp = np.stack([b3.exp_member(int(e), g.dh, P.f_e)[0] for e in e_h])
    P._mats = {}
    P.e_s = [int(e) for e in e_h]
    P.diag["q"], P.diag["k"] = q_rows, k_rows
    P.diag["s"] = (2.0 ** e_h).reshape(1, g.KV, g.G, 1, 1)
    return e_h, e_rng


def layer1_raw_per_head(ck, R, xc_f, rope_fc, chunk):
    """max |q_h . k| over the calibration set at layer 1, per query head (float)."""
    W0 = bl.load_layer(ck, 0, R)
    x1 = np.concatenate([tc.f_block(xc_f[s:s + chunk], W0, *rope_fc) for s in range(0, len(xc_f), chunk)])
    del W0
    W1 = bl.load_layer(ck, 1, R)
    raw_h = np.zeros(tc.GEO.H)
    for s in range(0, len(x1), chunk):
        _, parts = b3._f_block_parts(x1[s:s + chunk], W1, *rope_fc, tc.GEO)
        raw_h = np.maximum(raw_h, np.abs(parts["raw"]).max(axis=(0, 3, 4)).reshape(-1))
    return raw_h


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
    ap.add_argument("--export-name", default=None, help="export directory name (default: the run name)")
    ap.add_argument("--profile-from", default=None, help="prepass.json of a run whose profile decisions to reuse (skips the pre-pass)")
    ap.add_argument("--link-from", default=None, help="export dir whose byte-identical files to hard-link layer by layer")
    ap.add_argument("--l1-mode", default="none", choices=["none", "s16", "perhead", "m2zero", "s0m", "fe13", "sh7", "o16", "sh7o16"],
                    help="B6 experiments on LAYER 1 only (NOT native except m2zero/fe13): see FIDELITY_OPTIONS_8B.md")
    ap.add_argument("--check-against", default=None, help="export dir: compare every non-overridden layer's words")
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
    if args.profile_from:
        glob, caches, ptable = glob_from_prepass(Path(args.profile_from), var.tn), [{} for _ in range(L)], None
        log(f"profile decisions REUSED from {args.profile_from}")
    else:
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
    exp_root = HERE / "export" / (args.export_name or name)
    # B6 (18:3xZ): write_bin writes IN PLACE; a file left by an earlier (killed) run may be a hard link into
    # another export (--link-from), so writing over it would truncate the shared inode. Exports start fresh.
    if args.export and exp_root.exists() and any(exp_root.iterdir()):
        raise SystemExit(f"export dir {exp_root} exists and is not empty: remove it first (hard links; never write in place)")
    raw_h =layer1_raw_per_head(ck, R, xc_f, rope_fc, args.chunk) if args.l1_mode == "perhead" else None
    if raw_h is not None:
        log(f"layer-1 raw score max per query head: {np.round(raw_h, 1).tolist()}")
    word_mismatch = {}
    iso = slice(0, min(args.iso_seqs, len(ho_ids)))
    for l in range(L):
        tl = time.time()
        W = bl.load_layer(ck, l, R)
        var_l = var
        if l == 1 and args.l1_mode in ("s16", "m2zero", "fe13"):
            kw_l = dict(var.__dict__)
            kw_l.update({"s16": {"s16": True}, "m2zero": {"margin_pow2": 0.0}, "fe13": {"f_e": 13}}[args.l1_mode])
            var_l = b3.Variant(**kw_l)
        # B6 (21:4xZ) screens: o16 = layer-1 o in the int16 class (B4-3 knob, NOT native: o limbs);
        # sh7 = layer-1 SH_S 7 instead of the run-level 6 (e_s and all margins kept; native: per-layer SH_S)
        if l == 1 and args.l1_mode in ("o16", "sh7o16"):
            kw_l = dict(var.__dict__)
            kw_l["o16"] = True
            var_l = b3.Variant(**kw_l)
        glob_l = glob
        if l == 1 and args.l1_mode in ("sh7", "sh7o16"):
            glob_l = b3.Globals(**{**glob.__dict__, "shifts": dict(glob.shifts, s=7)})
        if l == 1 and args.l1_mode == "s0m":
            # B6 (21:3xZ): NO MARGIN ON THE SCORE EXPONENT ONLY (native: a per-layer table key). m2zero also dropped
            # the margin of the gate / act exponents, and layer 1's FFN gate then refused every chained sequence.
            # solve_layer calls b3.qk_scales by module-global name with m2 as positional argument 9.
            _qk = b3.qk_scales

            def _qk_score_nomargin(*a, **k):
                a = list(a)
                if len(a) > 9:
                    a[9] = 1.0
                else:
                    k["m2"] = 1.0
                return _qk(*a, **k)
            b3.qk_scales = _qk_score_nomargin
            try:
                P, rep = b3.solve_layer(W, stats[l], var_l, glob.s_in[l], glob.s_out[l], glob, caches[l])
            finally:
                b3.qk_scales = _qk
            log(f"layer-1 s0m: score e_s {P.e_s} (margin 1.0 on the score exponent only), silu {P.silu}")
        else:
            P, rep = b3.solve_layer(W, stats[l], var_l, glob.s_in[l], glob.s_out[l], glob_l, caches[l])
            if l == 1 and args.l1_mode in ("sh7", "o16", "sh7o16"):
                log(f"layer-1 {args.l1_mode}: e_s {P.e_s} sh_s {P.sh_s} sh_o {P.sh_o} sh_ao {P.sh_ao} silu {P.silu}")
        if l == 1 and args.l1_mode == "perhead":
            e_h, e_rng = perhead_qk(W, stats[l], var, P, rep, raw_h)
            rep["perhead"] = {"e_s": e_h.tolist(), "e_range": e_rng.tolist()}
            log(f"layer-1 per-head e_s {e_h.tolist()}")
        if args.check_against and not (l == 1 and args.l1_mode != "none"):
            man = json.loads((Path(args.check_against) / f"layer_{l:02d}" / "manifest.json").read_text())
            bad = [n for n in WORDS if man["arrays"][n]["sha256"] != word_sha(P, n)]
            if bad:
                word_mismatch[l] = bad
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
            if args.link_from:
                entry["hard_linked_files"] = link_identical(Path(args.link_from) / f"layer_{l:02d}", exp_root / f"layer_{l:02d}")
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
               "calibration": {"T_cal": T_cal, "sequences": len(cal_ids)}, "tool_sha256": tool_sha,
               "l1_mode": args.l1_mode, "profile_from": args.profile_from,
               "check_against": {"export": args.check_against, "layers_with_different_words": word_mismatch} if args.check_against else None}
    if args.check_against:
        log(f"words vs {args.check_against}: {len(word_mismatch)} layer(s) differ {word_mismatch}")
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
        for f_ in ("rotation_sign.bin", "rotation.json"):
            if (exp_root / f_).exists():
                (exp_root / f_).unlink()
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
