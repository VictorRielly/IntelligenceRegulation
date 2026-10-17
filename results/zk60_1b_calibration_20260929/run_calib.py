#!/usr/bin/env python3
"""Lane B driver: per-layer full-block integer calibration of TinyLlama-1.1B
and held-out validation of the exact integer stack against float32.

Pass 1 streams the 22 blocks once in float32 over the CALIBRATION sequences
and records every site maximum the solver needs. The residual scale(s) follow
from the whole stack. Pass 2 streams the blocks again; per block it solves the
integer constants, quantizes the weights, and runs

  * the integer block on the calibration set (chained from the embedding),
  * the integer block on the HELD-OUT set, chained (integer stack end to end),
  * the integer block on the held-out set, ISOLATED (input = the float
    activation of that layer, quantized), against the float block,

then the float final norm + LM head (outside the proved stack, per D13) on
both the float and the integer final residual: top-1 agreement, NLL/ppl, KL.

Range violations are counted per site and per sequence; the native kernel
would refuse every sequence with a violation. Continuing past one (clamped)
is diagnostic only and flagged in the output.
"""

from __future__ import annotations

import argparse
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np  # noqa: E402

import tlcalib as tc  # noqa: E402
from corpus import sequences  # noqa: E402
from spm_bpe import SpmBpe, tokenizer_selfcheck  # noqa: E402

try:
    from threadpoolctl import threadpool_limits
except ImportError:  # pragma: no cover
    threadpool_limits = None


def log(msg: str):
    print(f"[{time.strftime('%H:%M:%S', time.gmtime())}Z] {msg}", flush=True)


def run_int(x, P, rope, rec, chunk):
    outs = []
    for s in range(0, x.shape[0], chunk):
        outs.append(tc.i_block(x[s:s + chunk], P, rope, rec, seq0=s))
    return np.concatenate(outs)


def residual_scales(stats, margin, mode):
    L = len(stats)
    m = 1.0 + margin
    need_in = [max(st["x"], st["x1"]) * m / 32767.0 for st in stats]
    need_out = [st["x2"] * m / 32767.0 for st in stats]
    if mode == "global":
        s = max(max(need_in), max(need_out))
        return [s] * L, [s] * L
    # per-layer power-of-two exponents, non-decreasing (only coarsening is
    # expressible: x2 = requant(x1 + (z << k), k))
    base = need_in[0]
    e = [0] * (L + 1)
    for l in range(L):
        want_in = int(np.ceil(np.log2(max(need_in[l], 1e-30) / base) - 1e-12))
        e[l] = max(e[l - 1] if l else 0, want_in)
        want_out = int(np.ceil(np.log2(max(need_out[l], 1e-30) / base) - 1e-12))
        e[l + 1] = max(e[l], want_out)
    # the input of l+1 must also cover its own x / x1 (re-sweep)
    for l in range(1, L):
        want_in = int(np.ceil(np.log2(need_in[l] / base) - 1e-12))
        if e[l] < want_in:
            raise RuntimeError("non-monotone residual need; re-sweep required")
    s_in = [base * 2.0 ** e[l] for l in range(L)]
    s_out = [base * 2.0 ** e[l + 1] for l in range(L)]
    return s_in, s_out


def site_ratio(st_h, st_c):
    keys = ["x", "x1", "x2", "ao", "z", "q_pair", "k_pair", "v", "raw_all", "o", "gate", "up", "h"]
    out = {k: float(st_h[k] / st_c[k]) for k in keys if st_c.get(k)}
    out["xhat_a_ch"] = float(np.max(st_h["xhat_a_ch"] / np.maximum(st_c["xhat_a_ch"], 1e-12)))
    out["xhat_m_ch"] = float(np.max(st_h["xhat_m_ch"] / np.maximum(st_c["xhat_m_ch"], 1e-12)))
    return out


def summarize_cos(c):
    return {"mean": float(c.mean()), "min": float(c.min()), "p01": float(np.quantile(c, 0.01))}


def head_metrics(xf, xi, ids, norm_w, lm_head, chunk=4):
    agree, n, nll_f, nll_i, kl = 0, 0, 0.0, 0.0, 0.0
    agree_last = 0
    for s in range(0, xf.shape[0], chunk):
        lf = tc.f_head(xf[s:s + chunk], norm_w, lm_head).astype(np.float64)
        li = tc.f_head(xi[s:s + chunk], norm_w, lm_head).astype(np.float64)
        tgt = ids[s:s + chunk, 1:]
        lf, li = lf[:, :-1], li[:, :-1]
        agree += int((lf.argmax(-1) == li.argmax(-1)).sum())
        agree_last += int((lf[:, -1].argmax(-1) == li[:, -1].argmax(-1)).sum())
        n += tgt.size
        lsf = lf - lf.max(-1, keepdims=True)
        lsf -= np.log(np.exp(lsf).sum(-1, keepdims=True))
        lsi = li - li.max(-1, keepdims=True)
        lsi -= np.log(np.exp(lsi).sum(-1, keepdims=True))
        nll_f -= float(np.take_along_axis(lsf, tgt[..., None], -1).sum())
        nll_i -= float(np.take_along_axis(lsi, tgt[..., None], -1).sum())
        kl += float((np.exp(lsf) * (lsf - lsi)).sum())
    return {"positions": n, "top1_agreement": agree / n, "ppl_float": float(np.exp(nll_f / n)),
            "ppl_int": float(np.exp(nll_i / n)), "nll_float": nll_f / n, "nll_int": nll_i / n,
            "kl_float_to_int_mean": kl / n, "last_position_top1_agreement": agree_last / xf.shape[0]}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--variant", required=True)
    ap.add_argument("--T", type=int, default=128)
    ap.add_argument("--calib-per", type=int, default=3)
    ap.add_argument("--heldout-per", type=int, default=3)
    ap.add_argument("--layers", type=int, default=22)
    ap.add_argument("--margin", type=float, default=0.25)
    ap.add_argument("--smooth", type=float, default=None)
    ap.add_argument("--norm", default="calibrated", choices=["calibrated", "native"])
    ap.add_argument("--shifts", default="free", choices=["free", "native"])
    ap.add_argument("--tn", type=int, default=10)
    ap.add_argument("--f-e", type=int, default=9)
    ap.add_argument("--res", default="global", choices=["global", "perlayer"])
    ap.add_argument("--chunk", type=int, default=6)
    ap.add_argument("--save-weights", action="store_true")
    ap.add_argument("--no-head", action="store_true")
    args = ap.parse_args()

    out = tc.HERE / "runs" / args.variant
    out.mkdir(parents=True, exist_ok=True)
    wdir = tc.HERE / "weights" / args.variant
    if args.save_weights:
        wdir.mkdir(parents=True, exist_ok=True)
    opt = tc.CalibOptions(margin=args.margin, smooth_alpha=args.smooth, norm=args.norm, tn=args.tn,
                          shifts=args.shifts, f_e=args.f_e)
    t0 = time.time()
    log(f"variant {args.variant}: {vars(args)}")
    log(f"exact-mm selfcheck {tc.selfcheck_exact_mm()}")
    ck = tc.open_checkpoint()
    ident = {k: ck.identity[k] for k in ("schema", "config_sha256", "shard_sha256", "tensor_count", "payload_bytes", "geometry")}
    log(f"checkpoint pinned ({time.time()-t0:.0f}s): {ident['shard_sha256']}")
    tok = SpmBpe(tc.MODEL_DIR / "tokenizer.model")
    tcheck = tokenizer_selfcheck(tok)
    cal, cal_meta = sequences(tok, "calib", args.T, args.calib_per)
    ho, ho_meta = sequences(tok, "heldout", args.T, args.heldout_per)
    cal_ids, ho_ids = np.array(cal, dtype=np.int64), np.array(ho, dtype=np.int64)
    log(f"tokenizer selfcheck ok={all(c['ok'] for c in tcheck['cases'].values())}; calib {cal_ids.shape}, heldout {ho_ids.shape}")
    emb = tc.tensor_f32(ck.refs["model.embed_tokens.weight"])
    xc_f, xh_f = emb[cal_ids], emb[ho_ids]
    del emb
    T = args.T
    cos, sin = tc.rope_f32(T)
    rope_i = tc.rope_tables_int(T, tc.GEO.dh, tc.GEO.theta, opt.f_ro)
    L = args.layers

    # ---------------- pass 1: float calibration statistics
    stats = []
    x = xc_f
    for l in range(L):
        W = tc.layer_f32(ck, l)
        st = {}
        x = tc.f_block(x, W, cos, sin, st)
        stats.append(st)
    del x
    log(f"pass 1 (float calibration stats, {L} blocks) done ({time.time()-t0:.0f}s)")
    s_in, s_out = residual_scales(stats, args.margin, args.res)
    log(f"residual scales: in {[f'{s:.3g}' for s in s_in]}")

    # ---------------- pass 2
    rec_in_c, rec_in_h = tc.Rec(len(cal_ids)), tc.Rec(len(ho_ids))
    xi_c = tc.quantize_input(xc_f, s_in[0], rec_in_c)
    xi_h = tc.quantize_input(xh_f, s_in[0], rec_in_h)
    emb_cos = tc.cos_rows(xi_h * s_in[0], xh_f)
    log(f"embedding quantized at s_x {s_in[0]:.4g}: cos mean {emb_cos.mean():.5f} min {emb_cos.min():.4f}; "
        f"zero fraction {float((xi_h == 0).mean()):.3f}")
    xf_h = xh_f
    layers = []
    refused_c = np.zeros(len(cal_ids), dtype=bool)
    refused_h = np.zeros(len(ho_ids), dtype=bool)
    for l in range(L):
        tl = time.time()
        W = tc.layer_f32(ck, l)
        P, rep = tc.calibrate_layer(W, stats[l], s_in[l], opt, s_x_out=s_out[l])
        st_h = {}
        xf_h_next = tc.f_block(xf_h, W, cos, sin, st_h)
        del W
        rc, rh, ri = tc.Rec(len(cal_ids)), tc.Rec(len(ho_ids)), tc.Rec(len(ho_ids))
        xi_c = run_int(xi_c, P, rope_i, rc, args.chunk)
        xi_h_next = run_int(xi_h, P, rope_i, rh, args.chunk)
        xq = tc.quantize_input(xf_h, s_in[l], ri)
        xiso = run_int(xq, P, rope_i, ri, args.chunk)
        so, si = s_out[l], s_in[l]
        iso_cos = tc.cos_rows(xiso * so, xf_h_next)
        iso_dcos = tc.cos_rows(xiso * so - xq * si, xf_h_next - xf_h)
        ch_cos = tc.cos_rows(xi_h_next * so, xf_h_next)
        ch_dcos = tc.cos_rows(xi_h_next * so - xi_h * si, xf_h_next - xf_h)
        refused_c |= np.array([f is not None for f in rc.first])
        refused_h |= np.array([f is not None for f in rh.first])
        entry = {
            "layer": l, "constants": P.constants(), "calibration": rep,
            "isolated": {"cos": summarize_cos(iso_cos), "delta_cos": summarize_cos(iso_dcos),
                         "delta_rel_l2": tc.rel_l2(xiso * so - xq * si, xf_h_next - xf_h),
                         "range": ri.summary()},
            "chained": {"cos": summarize_cos(ch_cos), "delta_cos": summarize_cos(ch_dcos),
                        "rel_l2": tc.rel_l2(xi_h_next * so, xf_h_next), "range": rh.summary()},
            "calib_chained_range": rc.summary(),
            "heldout_over_calib_float_max": site_ratio(st_h, stats[l]),
        }
        layers.append(entry)
        if args.save_weights:
            words = tc.native_words(P, T)
            np.savez(wdir / f"layer_{l:02d}.npz", wq=P.wq, wk=P.wk, wv=P.wv, wo=P.wo, gamma_a=P.gamma_a,
                     gamma_m=P.gamma_m, wg_t=P.wg_t, wu_t=P.wu_t, wd_t=P.wd_t, exp=P.exp, act=P.act)
            entry["native_word_sha256"] = {k: tc.word_digest(v) for k, v in words.items()}
            entry["native_word_lengths"] = {k: int(v.size) for k, v in words.items()}
        (out / f"layer_{l:02d}.json").write_text(tc.jdump(entry))
        c = P.constants()
        log(f"L{l:02d} cn {c['cn_a']}/{c['cn_m']} ceps {c['ceps']} sh qkv{c['sh_qkv']} s{c['sh_s']} o{c['sh_o']} ao{c['sh_ao']} "
            f"g{c['sh_g']} h{c['sh_h']} z{c['sh_z']} r2{c['sh_r2']} | iso cos {iso_cos.mean():.5f} dcos {iso_dcos.mean():.4f} "
            f"(min {iso_dcos.min():.3f}) | chain cos {ch_cos.mean():.5f} dcos {ch_dcos.mean():.4f} | "
            f"viol iso {sum(s['violations'] for s in ri.summary()['sites'].values())} "
            f"chain {sum(s['violations'] for s in rh.summary()['sites'].values())} "
            f"cal {sum(s['violations'] for s in rc.summary()['sites'].values())} "
            f"refused seqs h/c {int(refused_h.sum())}/{int(refused_c.sum())} ({time.time()-tl:.0f}s)")
        xf_h, xi_h = xf_h_next, xi_h_next

    summary = {"variant": args.variant, "args": vars(args), "options": opt.__dict__, "checkpoint": ident,
               "tokenizer_selfcheck": tcheck, "calib_sequences": cal_meta, "heldout_sequences": ho_meta,
               "residual_scales_in": s_in, "residual_scales_out": s_out,
               "embedding_cos": summarize_cos(emb_cos),
               "input_range_heldout": rec_in_h.summary(), "input_range_calib": rec_in_c.summary(),
               "heldout_sequences_refused_any_layer": int(refused_h.sum()),
               "calib_sequences_refused_any_layer": int(refused_c.sum()),
               "layers_evaluated": L, "complete_stack": L == ck.config["layers"],
               "diagnostic_clamping": "values outside a class were clamped to continue; a native kernel refuses such a sequence",
               "seconds": time.time() - t0}
    if not args.no_head and L == ck.config["layers"]:
        norm_w = tc.tensor_f32(ck.refs["model.norm.weight"])
        lm_head = tc.tensor_f32(ck.refs["lm_head.weight"])
        summary["head"] = head_metrics(xf_h, xi_h * s_out[-1], ho_ids, norm_w, lm_head)
        log(f"head: {summary['head']}")
    summary["seconds"] = time.time() - t0
    (out / "summary.json").write_text(tc.jdump(summary))
    log(f"done ({time.time()-t0:.0f}s) -> {out}")


if __name__ == "__main__":
    if threadpool_limits is not None:
        with threadpool_limits(limits=2):
            main()
    else:
        main()
