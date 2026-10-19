#!/usr/bin/env python3
"""Fidelity parity evaluation: float model vs the export's integer model (or a
RELAXED variant of it, for error attribution) on perplexity corpora and
LAMBADA, with paired confidence intervals.

  [ZK60_MODEL=llama3-8b] python3 fp_eval.py --export DIR --corpora fineweb:128,wikitext:128,lambada:1000 \
      [--relax FAMILY|SITE,...] [--head int|float] --tag NAME

Float reference: the original (unrotated) float32 model, HF semantics
(tlcalib.f_block + float32 final norm + LM head); its final residual is
cached per corpus set (runs/<model>/float_T<T>_<ids sha>.npy).
Integer model: the export's words through fp_lib.rx_block (all sites exact =
tlcalib.i_block bit for bit), input = the export's int16 embedding table,
head = the D25 T4 integer head (8B: the export's token_io words; TinyLlama:
built here by the same rule) unless --head float or the head is relaxed.
Range violations are counted per sequence (the native kernel would refuse);
values are clamped to continue (diagnostic) and metrics are given over all
sequences and over the accepted ones.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import sys
import time
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import fp_lib as fl  # noqa: E402
import fp_data  # noqa: E402
from fp_lib import tc, b3, GEO  # noqa: E402


def float_final(ids, T, cache: Path, chunk: int):
    if cache.exists():
        fl.log(f"float final residual from cache {cache.name}")
        return np.load(cache, mmap_mode="r")
    ck = fl.checkpoint()
    x = fl.emb_rows(ids)
    rope = tc.rope_f32(T)
    t0 = time.time()
    for l in range(ck.config["layers"]):
        W = tc.layer_f32(ck, l)
        x = np.concatenate([tc.f_block(x[s:s + chunk], W, *rope) for s in range(0, len(x), chunk)])
        del W
        if l % 4 == 0:
            fl.log(f"  float L{l:02d} ({time.time() - t0:.0f}s)")
    tmp = cache.with_suffix(f".tmp{os.getpid()}.npy")
    np.save(tmp, x.astype(np.float32))
    os.replace(tmp, cache)
    fl.log(f"float final residual cached ({time.time() - t0:.0f}s)")
    return x


def int_head_for(ex: fl.Export, runs: Path, ids_cal_fn=None):
    """8B: the export's token_io head words (checked against the rule); TinyLlama: built by the D25 T4 rule here."""
    pc = ex.prof["profile_constants"]
    tn = int(pc["norm_tn"]) if pc.get("norm_tn") else int(ex.layer(0)["c"]["norm_tn"])
    ceps = int(pc["norm_ceps"]) if pc.get("norm_ceps") else int(ex.layer(0)["c"]["norm_ceps"])
    s_out = ex.s_out[-1]
    hm = ex.root / "token_io" / "head_manifest.json"
    if hm.exists():
        man = json.loads(hm.read_text())
        fn = man["final_norm"]
        assert fn["tn"] == tn and fn["ceps"] == ceps
        seed = int(ex.prof["metadata_out_of_proof"]["rotation"]["seed"])
        cache = runs / f"inthead_words_seed{seed}.npz"
        if not cache.exists() and (runs / "inthead_llama3_8b_pg_rot1_b7_T128.npz").exists():
            cache = runs / "inthead_llama3_8b_pg_rot1_b7_T128.npz"      # same rule, same rotation: same words
        head = fl.IntHead(ex.R, s_out, tn, ceps, int(fn["cn_calibrated"]), cache=cache)
        wr = np.memmap(ex.root / "token_io" / "head_int8_perrow.bin", dtype=np.int8, mode="r").reshape(-1, GEO.d)
        mult = np.frombuffer((ex.root / "token_io" / "head_mult12.bin").read_bytes(), dtype="<i8")
        assert np.array_equal(head.mult.astype(np.int64), mult), "multipliers differ from the export's"
        assert np.array_equal(head.Wr, wr), "head words differ from the export's"
        return head, {"source": "export token_io (checked equal to the rule)", "cn": int(fn["cn_calibrated"]), "tn": tn, "ceps": ceps}
    info = build_final_norm_tinyllama(ex, tn, ceps, s_out, runs)
    seed = int(ex.prof["metadata_out_of_proof"]["rotation"]["seed"])
    head = fl.IntHead(ex.R, s_out, tn, ceps, int(info["cn"]), cache=runs / f"inthead_words_seed{seed}.npz")
    return head, info


def build_final_norm_tinyllama(ex, tn, ceps, s_out, runs):
    """The 8B rule (b8_token_io.norm_constants) at TinyLlama: float model on the
    calibration lane's b4 calibration set (54 licence/docstring + 54 FineWeb row
    group 0 sequences at T), per-channel max |xhat'| of the rotated final
    residual, tlcalib.norm_site(c = 1) at margin 0.5."""
    sys.path.insert(0, str(fl.CAL))
    from corpus import sequences
    import corpus4
    from spm_bpe import SpmBpe
    T = ex.T
    tok = SpmBpe(tc.MODEL_DIR / "tokenizer.model")
    cal, _ = sequences(tok, "calib", T, 6)
    c2, _ = corpus4.fineweb_sequences(tok, "calib", T, 54)
    ids = np.array(cal + c2, dtype=np.int64)
    seed = int(ex.prof["metadata_out_of_proof"]["rotation"]["seed"])
    chp = runs / f"final_xhat_rot_absmax_T{T}_seed{seed}_{hashlib.sha256(ids.tobytes()).hexdigest()[:12]}.npy"
    if chp.exists():
        ch = np.load(chp)
    else:
        x = float_final(ids, T, runs / f"float_cal_T{T}_{hashlib.sha256(ids.tobytes()).hexdigest()[:12]}.npy", 8)
        xr = ex.R.fwd(np.asarray(x).reshape(-1, GEO.d).astype(np.float64))
        xh = xr / np.sqrt(np.mean(xr * xr, axis=-1, keepdims=True) + GEO.eps)
        ch = np.abs(xh).max(0)
        tmp = chp.with_name(chp.stem + f".tmp{os.getpid()}.npy")
        np.save(tmp, ch)
        os.replace(tmp, chp)
    nrep = {}
    g8, cn, tn_s, ceps_s, s_y, _ = tc.norm_site(np.ones(GEO.d), ch, [], "final_norm", tc.CalibOptions(margin=0.5, tn=tn),
                                                s_out, nrep, "final_norm")
    assert tn_s == tn and int(ceps_s) == ceps and np.all(g8 == 127), (tn_s, ceps_s, g8[:3])
    return {"source": "built by fp_eval (8B rule at TinyLlama, b4 calibration set)", "cn": int(cn), "tn": tn, "ceps": ceps,
            "calib_sequences": int(len(ids)), "xhat_rot_absmax": float(ch.max())}


def refusal_tokens(vw):
    """(layer, site, token) -> number of sequences, with the decoded token text."""
    agg = {}
    for v in vw:
        k = (v["layer"], v["site"], v["token"])
        agg.setdefault(k, set()).add(v["seq"])
    try:
        tok = fp_data.Tok(fl.MODEL)
        dec = (lambda t: tok.tk.id_to_token(t)) if fl.IS8B else (lambda t: tok.tk.decode([t]))
    except Exception:  # pragma: no cover
        dec = str
    out = [{"layer": k[0], "site": k[1], "token": k[2], "text": dec(k[2]), "sequences": len(v)} for k, v in agg.items()]
    return sorted(out, key=lambda r: (-r["sequences"], r["layer"]))


def ci_ratio(d):
    """paired per-sequence mean NLL differences -> ppl ratio, 95% t-interval and bootstrap interval."""
    d = np.asarray(d, dtype=np.float64)
    n = len(d)
    m = float(d.mean())
    se = float(d.std(ddof=1) / math.sqrt(n)) if n > 1 else float("nan")
    rng = np.random.default_rng(7)
    bs = d[rng.integers(0, n, size=(2000, n))].mean(1)
    return {"ratio": math.exp(m), "ci95_t": [math.exp(m - 1.96 * se), math.exp(m + 1.96 * se)],
            "ci95_boot": [math.exp(float(np.quantile(bs, 0.025))), math.exp(float(np.quantile(bs, 0.975)))], "n": n}


def aggregate(meta, mask, per, refused):
    """per-corpus metrics from per-position arrays."""
    out = {}
    seq = per["seq"]
    corp = np.array([m["corpus"] for m in meta])
    for c in dict.fromkeys(corp.tolist()):
        sel_seq = np.nonzero(corp == c)[0]
        res = {}
        for subset, keep in (("all", np.ones(len(meta), dtype=bool)), ("accepted", ~refused)):
            sseq = [i for i in sel_seq if keep[i]]
            if not sseq:
                continue
            pm = np.isin(seq, sseq)
            nf, ni = per["nll_f"][pm], per["nll_i"][pm]
            r = {"sequences": len(sseq), "positions": int(pm.sum()),
                 "top1_agreement": float((per["arg_f"][pm] == per["arg_i"][pm]).mean()),
                 "kl_mean": float(per["kl"][pm].mean())}
            if c == "lambada":
                tg = per["tgt"][pm]
                okf, oki = {}, {}
                for s_, af, ai, t_ in zip(seq[pm], per["arg_f"][pm], per["arg_i"][pm], tg):
                    okf[s_] = okf.get(s_, True) and af == t_
                    oki[s_] = oki.get(s_, True) and ai == t_
                a_f = np.array([okf[s_] for s_ in sseq], dtype=float)
                a_i = np.array([oki[s_] for s_ in sseq], dtype=float)
                dd = a_i - a_f
                n = len(dd)
                se = float(dd.std(ddof=1) / math.sqrt(n)) if n > 1 else float("nan")
                r.update({"acc_float": float(a_f.mean()), "acc_int": float(a_i.mean()), "acc_diff": float(dd.mean()),
                          "acc_diff_ci95": [float(dd.mean() - 1.96 * se), float(dd.mean() + 1.96 * se)],
                          "discordant": {"int_only": int((dd > 0).sum()), "float_only": int((dd < 0).sum())},
                          "acc_float_se": float(a_f.std(ddof=1) / math.sqrt(n)) if n > 1 else None})
                # target log-likelihood per item
                tf = np.array([nf[seq[pm] == s_].sum() for s_ in sseq])
                ti = np.array([ni[seq[pm] == s_].sum() for s_ in sseq])
                r["target_nll_float"] = float(tf.mean())
                r["target_nll_int"] = float(ti.mean())
            else:
                df = np.array([nf[seq[pm] == s_].mean() for s_ in sseq])
                di = np.array([ni[seq[pm] == s_].mean() for s_ in sseq])
                r["ppl_float"] = float(np.exp(nf.mean()))
                r["ppl_int"] = float(np.exp(ni.mean()))
                r["ppl_ratio"] = ci_ratio(di - df)
            res[subset] = r
        res["refused"] = int(refused[sel_seq].sum())
        out[c] = res
    return out


def main():
    if (fl.HERE / "logs" / "HOLD").exists() and os.environ.get("FP_ALLOW") != "1":
        fl.log("DEFERRED: lane hold (logs/HOLD); re-run through logs/stream.sh")
        raise SystemExit(3)
    ap = argparse.ArgumentParser()
    ap.add_argument("--export", required=True)
    ap.add_argument("--corpora", default="fineweb:48,wikitext:48")
    ap.add_argument("--relax", default="", help="comma list of families/sites to RELAX (float); empty = the integer model")
    ap.add_argument("--head", default="int", choices=["int", "float"])
    ap.add_argument("--tag", required=True)
    ap.add_argument("--chunk", type=int, default=4)
    ap.add_argument("--pos-chunk", type=int, default=512)
    ap.add_argument("--float-only", action="store_true")
    ap.add_argument("--no-verify", action="store_true", help="skip per-array sha256 of the export words")
    ap.add_argument("--gptq", default="", help="calibration corpora for GPTQ word rounding at fixed scales, e.g. fwcal:64")
    ap.add_argument("--gptq-damp", type=float, default=0.01)
    ap.add_argument("--words-from", default="", help="tag of an earlier run whose saved words replace the export's")
    ap.add_argument("--save-words", action="store_true")
    ap.add_argument("--mods", default="", help="what-if relation changes, comma list: pround")
    ap.add_argument("--gate-pc", default="", help="WHAT-IF per-channel-group SiLU: 'EMIN[:sat]' e.g. -5 or -8:sat")
    a = ap.parse_args()
    if (fl.HERE / "logs" / f"HOLD_{a.tag}").exists() or (fl.HERE / "logs" / f"HOLD2_{a.tag}").exists():
        fl.log(f"DEFERRED: per-tag hold logs/HOLD_{a.tag}")
        raise SystemExit(3)
    t0 = time.time()
    ex = fl.Export(Path(a.export), verify=not a.no_verify)
    T = ex.T
    runs = fl.HERE / "runs" / fl.MODEL
    runs.mkdir(parents=True, exist_ok=True)
    out = runs / a.tag
    out.mkdir(parents=True, exist_ok=True)
    relax = fl.parse_relax(a.relax)
    if a.head == "float":
        relax = relax | {"head"}
    exact = frozenset(fl.SITES) - relax
    fl.log(f"fp_eval {fl.MODEL} export {ex.root.name} T {T} corpora {a.corpora} relax {sorted(relax)} "
           f"threads {os.environ.get('OPENBLAS_NUM_THREADS')}")
    ids, meta, mask, info = fp_data.build(fl.MODEL, T, a.corpora)
    fl.log(f"corpora built: {ids.shape}, {info['corpora']} ({time.time() - t0:.0f}s)")
    xf = float_final(ids, T, runs / f"float_T{T}_{info['ids_sha256'][:12]}.npy", a.chunk)
    if a.float_only:
        return
    # ---------------- integer / relaxed stack
    if "emb" in exact:
        try:
            tab = ex.embedding_table()
            x = np.asarray(tab[ids.reshape(-1)], dtype=np.float64).reshape(*ids.shape, GEO.d)
        except FileNotFoundError:   # pseudo-export: TOKEN_IO_SPEC rule on the rows used
            x = np.floor(ex.R.fwd(fl.emb_rows(ids).reshape(-1, GEO.d)).astype(np.float32).astype(np.float64) / ex.s_in[0] + 0.5)
            assert np.abs(x).max() <= 32767, "an embedding row leaves int16 (that token would refuse)"
            x = x.reshape(*ids.shape, GEO.d)
    else:
        x = ex.R.fwd(fl.emb_rows(ids).reshape(-1, GEO.d)).astype(np.float32).astype(np.float64).reshape(*ids.shape, GEO.d) / ex.s_in[0]
    need_real = any(s.startswith("w_") for s in relax) or bool(a.gptq)
    xc, gptq_rep = None, []
    if a.gptq:
        import fp_gptq
        cids, _, _, cinfo = fp_data.build(fl.MODEL, T, a.gptq)
        assert not (set(map(tuple, cids.tolist())) & set(map(tuple, ids.tolist()))), "GPTQ calibration overlaps evaluation"
        xc = np.floor(ex.R.fwd(fl.emb_rows(cids).reshape(-1, GEO.d)).astype(np.float32).astype(np.float64) / ex.s_in[0] + 0.5
                      ).reshape(*cids.shape, GEO.d)
        fl.log(f"GPTQ calibration {cids.shape} {cinfo['corpora']}")
    wsrc = (runs / a.words_from) if a.words_from else None
    stats = None
    if a.gate_pc:
        import pickle
        sp = (fl.C8 / "runs" / "b5_stats_T128_n30_r1_L32.pkl") if fl.IS8B else (fl.CAL / "runs" / "b3_stats4_T128_c6_r1_b4fw54.pkl")
        stats = pickle.load(open(sp, "rb"))
        gtoks = a.gate_pc.split(":")
        gpc_min = int(gtoks[0])
        gpc_sat = "sat" in gtoks[1:]
        gpc_mc = next((float(t[2:]) for t in gtoks[1:] if t.startswith("mc")), 2.0)
    gpc_rep = []
    viol_where = []
    rec = tc.Rec(len(ids))
    first = [None] * len(ids)
    layers = []
    ck = fl.checkpoint()
    for l in range(ex.L):
        tl = time.time()
        Lw = ex.layer(l)
        assert abs(ex.s_in[l] - ex.s_out[l]) < 1e-15 and (l == 0 or abs(ex.s_in[l] - ex.s_out[l - 1]) < 1e-15)
        Wreal, wrep = (None, None)
        if need_real:
            Wreal, wrep = fl.real_weights(b3.rotate_layer(tc.layer_f32(ck, l), ex.R), Lw)
        if wsrc is not None:
            z = np.load(wsrc / f"words_L{l:02d}.npz")
            Lw = {"w": {**Lw["w"], **{k: z[k] for k in z.files}}, "c": Lw["c"], "manifest": Lw["manifest"]}
        if a.gptq:
            tg = time.time()
            neww, grep = fp_gptq.gptq_layer(Lw, Wreal, T, xc, a.chunk, a.gptq_damp)
            Lw = {"w": neww, "c": Lw["c"], "manifest": Lw["manifest"]}
            gptq_rep.append({"layer": l, **grep})
            fl.log(f"  GPTQ L{l:02d}: " + " ".join(f"{k} {v['rel_err_rtn']:.2e}->{v['rel_err_gptq']:.2e}" for k, v in grep.items())
                   + f" ({time.time() - tg:.0f}s)")
            Mc = fl.LayerModel(Lw, T)
            rc = tc.Rec(len(xc))
            xc = np.concatenate([fl.rx_block(xc[s:s + a.chunk], Mc, frozenset(fl.SITES), rc, seq0=s) for s in range(0, len(xc), a.chunk)])
            del Mc
        if a.save_words:
            np.savez(out / f"words_L{l:02d}.npz", **{k: Lw["w"][k] for k in ("wq", "wk", "wv", "wo", "wg_t", "wu_t", "wd_t")})
        M = fl.LayerModel(Lw, T, Wreal, frozenset(m for m in a.mods.split(",") if m))
        if stats is not None:
            ej, eoj, tabs, sat, grep_ = fl.gate_groups(stats[l], gpc_min, mc=gpc_mc, sat=gpc_sat)
            M.gate_pc = (ej, eoj, tabs, sat)
            gpc_rep.append({"layer": l, **grep_})
        r = fl.RecPos(len(ids))
        # stored float32 between layers: exact for the integer residual (|x| <= 32767 < 2^24); relaxed runs lose
        # only float32 rounding on the residual
        x = np.concatenate([fl.rx_block(x[s:s + a.chunk], M, exact, r, seq0=s).astype(np.float32) for s in range(0, len(ids), a.chunk)])
        for (site, si, pi), cnt in r.where.items():
            viol_where.append({"layer": l, "site": site, "seq": si, "pos": pi, "token": int(ids[si, pi]), "count": cnt,
                               "corpus": meta[si]["corpus"]})
        del M, Wreal
        for i, f in enumerate(r.first):
            if f is not None and first[i] is None:
                first[i] = (l, f)
        nv = sum(s["violations"] for s in r.summary()["sites"].values())
        layers.append({"layer": l, "violations": nv, "refused_new": sum(1 for f in r.first if f), "seconds": time.time() - tl,
                       "weight_fit": wrep})
        fl.log(f"L{l:02d} violations {nv} refused so far {sum(1 for f in first if f)} ({time.time() - tl:.0f}s)")
    refused = np.array([f is not None for f in first])
    # ---------------- heads + metrics
    s_out = ex.s_out[-1]
    fh = fl.FloatHead()
    head_info = {"kind": "float head on the dequantized, un-rotated integer residual"}
    ih = None
    if "head" in exact:
        ih, head_info = int_head_for(ex, runs)
        head_info["kind"] = "D25 T4 integer head (per-row int8 + 12-bit multipliers, final norm g0 127)"
    sq, ps = np.nonzero(mask)
    tgt = ids[sq, ps + 1]
    per = {k: [] for k in ("nll_f", "nll_i", "arg_f", "arg_i", "kl")}
    hrec = tc.Rec(1)
    for p0 in range(0, len(sq), a.pos_chunk):
        s_, p_ = sq[p0:p0 + a.pos_chunk], ps[p0:p0 + a.pos_chunk]
        hf = np.asarray(xf[s_, p_], dtype=np.float32)
        xi = x[s_, p_]
        bf = fh.logit_blocks(hf)
        if ih is not None:
            bi = ih.logit_blocks(xi, hrec)
        else:
            bi = fh.logit_blocks(ex.R.inv(xi * s_out).astype(np.float32))
        m = fl.stream_metrics(bf, bi, tgt[p0:p0 + a.pos_chunk])
        for k in per:
            per[k].append(m[k])
    per = {k: np.concatenate(v) for k, v in per.items()}
    per["seq"], per["pos"], per["tgt"] = sq, ps, tgt
    np.savez_compressed(out / "per_position.npz", **per, refused=refused)
    agg = aggregate(meta, mask, per, refused)
    summary = {"model": fl.MODEL, "export": str(ex.root), "export_profile_sha256": fl.sha_file(ex.root / "profile.json"),
               "T": T, "corpora": info, "relax": sorted(relax), "exact_sites": sorted(exact), "head": head_info,
               "head_final_norm_violations": sum(s["violations"] for s in hrec.summary()["sites"].values()),
               "refused": int(refused.sum()), "first_refusal": [None if f is None else {"layer": f[0], "site": f[1]} for f in first],
               "layers": layers, "metrics": agg, "seconds": time.time() - t0,
               "violations_where": viol_where[:5000],
               "refusal_tokens": refusal_tokens(viol_where),
               "gptq": {"calibration": a.gptq, "damp": a.gptq_damp, "per_layer": gptq_rep} if a.gptq else None,
               "words_from": a.words_from or None, "mods": a.mods or None,
               "gate_pc": {"spec": a.gate_pc, "per_layer": gpc_rep} if a.gate_pc else None,
               "tool_sha256": {p: fl.sha_file(fl.HERE / p) for p in ("fp_lib.py", "fp_data.py", "fp_eval.py", "fp_gptq.py")},
               "scope": "fidelity data, not a proof, not a privacy claim; refusals clamped to continue (diagnostic)"}
    (out / "summary.json").write_text(json.dumps(summary, indent=1, default=lambda o: o.item() if hasattr(o, "item") else str(o)))
    for c, r in agg.items():
        al = r["all"]
        if c == "lambada":
            fl.log(f"{c}: acc float {al['acc_float']:.4f} int {al['acc_int']:.4f} diff {al['acc_diff']:+.4f} "
                   f"CI {al['acc_diff_ci95']} top1 {al['top1_agreement']:.3f} refused {r['refused']}")
        else:
            pr = al["ppl_ratio"]
            fl.log(f"{c}: ppl float {al['ppl_float']:.3f} int {al['ppl_int']:.3f} ratio {pr['ratio']:.4f} CI {pr['ci95_t']} "
                   f"top1 {al['top1_agreement']:.3f} KL {al['kl_mean']:.4f} refused {r['refused']}")
    fl.log(f"done ({time.time() - t0:.0f}s) -> {out}")


if __name__ == "__main__":
    try:
        from threadpoolctl import threadpool_limits
        with threadpool_limits(limits=int(os.environ.get("OPENBLAS_NUM_THREADS", "4"))):
            main()
    except ImportError:
        main()
