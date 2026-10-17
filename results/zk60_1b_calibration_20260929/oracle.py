#!/usr/bin/env python3
"""Lane B2 diagnostic: WHERE the integer block loses the trained model.

A float "fake-quantization oracle". It uses the SAME per-layer calibration
the integer run uses (same solver, same options, same scales, the same int8
weights and tables), but runs the block in float and switches the integer
effects on one site at a time:

  emb    embedding rounded to the int16 residual grid
  norm_a / norm_m   norm outputs rounded to their int8 grid (gains + fold)
  ceps   epsilon replaced by the integer Ceps at this residual scale
  w      all seven weight matrices replaced by their dequantized int8 words
  q k v  projections rounded to int8           rope  the 2^-7 RoPE tables
  qr kr  rotated q/k rounded to int8           s     scores rounded to int8
  exp    softmax via the public exp table      p     probabilities floored to 2^-9
  o      attention output rounded to int8      ao    O-projection rounded to the residual grid
  gate   gate rounded to int8   act  SiLU through the public table
  up     up rounded to int16    h    product rounded to int16
  z      down projection rounded to the residual grid

For each configuration (float, each site alone, all sites, all-but-one) the
held-out stack is run end to end and compared with the float model through
the float final norm + LM head (outside the proved stack, D13): top-1
agreement and KL. "all" approximates the exact integer block (not bit-exact:
the integer norm uses isqrt and Ceps, the softmax an integer quotient); the
exact numbers are run_calib.py's. Out-of-range values are clamped here and
COUNTED per site (the native kernel refuses them). Diagnostic only.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np  # noqa: E402

import tlcalib as tc  # noqa: E402
import run_calib as rcal  # noqa: E402
from corpus import sequences  # noqa: E402
from spm_bpe import SpmBpe  # noqa: E402

try:
    from threadpoolctl import threadpool_limits
except ImportError:  # pragma: no cover
    threadpool_limits = None

SITES = ["emb", "norm_a", "ceps", "w", "q", "k", "v", "rope", "qr", "kr", "s", "exp", "p", "o", "ao",
         "norm_m", "gate", "act", "up", "h", "z"]
I16 = (-32768, 32767)


def fq_block(x, W, P, rep, rope_f, rope_i, on, cnt, s_in, s_out, g=tc.GEO):
    N, T, d = x.shape
    sc = rep["scales"]
    f32 = np.float32

    def rnd(a, s, lo, hi, name):
        q = np.floor(a.astype(np.float64) / s + 0.5)
        bad = (q < lo) | (q > hi)
        nb = int(bad.sum())
        if nb:
            cnt[name] = cnt.get(name, 0) + nb
        return (np.clip(q, lo, hi) * s).astype(f32)

    eps = g.eps
    if "ceps" in on:
        eps = float(P.ceps) * s_in * s_in / d

    def norm(xx, g8, s_gamma, s_y, site):
        xh = tc.f_xhat(xx, eps)
        y = xh * (g8.astype(np.float64) * s_gamma).astype(f32)
        if site in on:
            y = rnd(y, s_y, -127, 127, site)
        return y

    fa, fm = P.fold_a.astype(f32), P.fold_m.astype(f32)
    if "w" in on:
        Wq, Wk, Wv = (P.wq * f32(sc["s_wq"])), (P.wk * f32(sc["s_wk"])), (P.wv * f32(sc["s_wv"]))
        Wo = P.wo * f32(sc["s_wo"])
        Wg, Wu = P.wg_t.T * f32(sc["s_wg"]), P.wu_t.T * f32(sc["s_wu"])
        Wd = P.wd_t.T * f32(sc["s_wd"])
    else:
        Wq, Wk, Wv = (W[f"self_attn.{n}_proj.weight"] * fa[None, :] for n in "qkv")
        Wo = W["self_attn.o_proj.weight"]
        Wg, Wu = (W[f"mlp.{n}_proj.weight"] * fm[None, :] for n in ("gate", "up"))
        Wd = W["mlp.down_proj.weight"]
    Wq, Wk, Wv, Wo, Wg, Wu, Wd = (np.ascontiguousarray(a, dtype=f32) for a in (Wq, Wk, Wv, Wo, Wg, Wu, Wd))

    y = norm(x, P.gamma_a, rep["norm_a"]["s_gamma"], sc["s_y_a"], "norm_a")
    q = (y @ Wq.T).reshape(N, T, g.H, g.dh)
    k = (y @ Wk.T).reshape(N, T, g.KV, g.dh)
    v = (y @ Wv.T).reshape(N, T, g.KV, g.dh)
    if "q" in on:
        q = rnd(q, sc["s_q"], -127, 127, "q")
    if "k" in on:
        k = rnd(k, sc["s_k"], -127, 127, "k")
    if "v" in on:
        v = rnd(v, sc["s_v"], -127, 127, "v")
    if "rope" in on:
        c_i, s_i = rope_i
        cos, sin = (c_i / 2.0 ** P.f_ro).astype(f32), (s_i / 2.0 ** P.f_ro).astype(f32)
    else:
        cos, sin = rope_f
    qr, kr = tc.f_rope(q, cos, sin), tc.f_rope(k, cos, sin)
    ro = 2.0 ** (P.f_ro - P.sh_rope)
    if "qr" in on:
        qr = rnd(qr, sc["s_q"] * ro, -127, 127, "qr")
    if "kr" in on:
        kr = rnd(kr, sc["s_k"] * ro, -127, 127, "kr")
    qg = qr.reshape(N, T, g.KV, g.G, g.dh).transpose(0, 2, 3, 1, 4)
    kg = kr.transpose(0, 2, 3, 1)[:, :, None]
    raw = qg @ kg
    tri = np.tril(np.ones((T, T), dtype=bool))
    if "s" in on or "exp" in on:
        s8 = np.floor(raw.astype(np.float64) / sc["s_s"] + 0.5)
        bad = (s8 < -127) | (s8 > 127)
        if "s" in on and bad.any():
            cnt["s"] = cnt.get("s", 0) + int(bad.sum())
        s8 = np.clip(s8, -127, 127)
    if "exp" in on:
        masked = np.where(tri, s8, tc.Native.MASK).astype(np.int64)
        delta = masked.max(-1, keepdims=True) - masked
        if (delta > 255).any():
            cnt["exp"] = cnt.get("exp", 0) + int((delta > 255).sum())
        E = np.where(tri, P.exp[np.minimum(delta, 255)], 0).astype(np.float64)
        p = (E / E.sum(-1, keepdims=True)).astype(f32)
    else:
        lg = (s8 * sc["s_s"]).astype(f32) if "s" in on else raw
        logits = np.where(tri, lg / np.float32(np.sqrt(g.dh)), -np.inf).astype(f32)
        logits -= logits.max(-1, keepdims=True)
        p = np.exp(logits)
        p /= p.sum(-1, keepdims=True)
    if "p" in on:
        p = (np.floor(p.astype(np.float64) * 2.0 ** P.f_p) / 2.0 ** P.f_p).astype(f32)
    vg = v.transpose(0, 2, 1, 3)[:, :, None]
    o = (p @ vg).transpose(0, 3, 1, 2, 4).reshape(N, T, d)
    if "o" in on:
        o = rnd(o, sc["s_o"], -127, 127, "o")
    ao = o @ Wo.T
    if "ao" in on:
        ao = rnd(ao, s_in, *I16, "ao")
    x1 = x + ao
    ym = norm(x1, P.gamma_m, rep["norm_m"]["s_gamma"], sc["s_y_m"], "norm_m")
    gt = ym @ Wg.T
    up = ym @ Wu.T
    if "gate" in on:
        g8 = np.clip(np.floor(gt.astype(np.float64) / sc["s_g8"] + 0.5), -128, 127)
        nb = int(((gt / sc["s_g8"] + 0.5 < -128) | (gt / sc["s_g8"] + 0.5 >= 128)).sum())
        if nb:
            cnt["gate"] = cnt.get("gate", 0) + nb
        gt = (g8 * sc["s_g8"]).astype(f32)
    if "act" in on and "gate" in on:
        a = (P.act.astype(np.float64)[(g8 + 128).astype(np.int64)] * sc["s_act"]).astype(f32)
    else:
        a = gt / (1.0 + np.exp(-gt))
        if "act" in on:
            a = rnd(a, sc["s_act"], -32767, 32767, "act")
    if "up" in on:
        up = rnd(up, sc["s_u"], *I16, "up")
    hh = a * up
    if "h" in on:
        hh = rnd(hh, sc["s_h"], *I16, "h")
    z = hh @ Wd.T
    if "z" in on:
        z = rnd(z, s_out, *I16, "z")
    x2 = x1 + z
    if s_out != s_in and ("z" in on or "ao" in on):
        x2 = rnd(x2, s_out, *I16, "x2")
    return x2


def head_logprobs(x, norm_w, lm_head, chunk=4):
    out = []
    for s in range(0, x.shape[0], chunk):
        lf = tc.f_head(x[s:s + chunk], norm_w, lm_head).astype(np.float64)[:, :-1]
        lf -= lf.max(-1, keepdims=True)
        lf -= np.log(np.exp(lf).sum(-1, keepdims=True))
        out.append(lf.astype(np.float32))
    return np.concatenate(out)


def compare(lf, li, ids):
    tgt = ids[:, 1:]
    top = float((lf.argmax(-1) == li.argmax(-1)).mean())
    kl = float((np.exp(lf.astype(np.float64)) * (lf - li)).sum(-1).mean())
    nll = -float(np.take_along_axis(li, tgt[..., None], -1).mean())
    return {"top1": top, "kl": kl, "nll": nll, "ppl": float(np.exp(nll))}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--variant", required=True)
    ap.add_argument("--T", type=int, default=32)
    ap.add_argument("--calib-per", type=int, default=1)
    ap.add_argument("--heldout-per", type=int, default=1)
    ap.add_argument("--margin", type=float, default=0.25)
    ap.add_argument("--smooth", type=float, default=None)
    ap.add_argument("--norm", default="calibrated", choices=["calibrated", "native", "profile"])
    ap.add_argument("--shifts", default="free", choices=["free", "native"])
    ap.add_argument("--tn", type=int, default=10)
    ap.add_argument("--f-e", type=int, default=9)
    ap.add_argument("--res", default="global", choices=["global", "perlayer", "perlayer-top"])
    ap.add_argument("--configs", default="singles,all,loo")
    rcal.add_solver_args(ap)
    args = ap.parse_args()
    out = tc.HERE / "oracle" / args.variant
    out.mkdir(parents=True, exist_ok=True)
    opt = rcal.options_from_args(args)
    t0 = time.time()
    rcal.log(f"oracle {args.variant}: {vars(args)}")
    ck = tc.open_checkpoint()
    tok = SpmBpe(tc.MODEL_DIR / "tokenizer.model")
    cal, _ = sequences(tok, "calib", args.T, args.calib_per)
    ho, ho_meta = sequences(tok, "heldout", args.T, args.heldout_per)
    cal_ids, ho_ids = np.array(cal, dtype=np.int64), np.array(ho, dtype=np.int64)
    emb = tc.tensor_f32(ck.refs["model.embed_tokens.weight"])
    xc, xh = emb[cal_ids], emb[ho_ids]
    del emb
    T = args.T
    rope_f = tc.rope_f32(T)
    rope_i = tc.rope_tables_int(T, tc.GEO.dh, tc.GEO.theta, opt.f_ro)
    L = ck.config["layers"]
    stats = rcal.float_stats(ck, xc, rope_f, L, opt)
    s_in, s_out = rcal.residual_scales(stats, args.margin, args.res)
    profile = rcal.profile_constants(stats, opt)
    rcal.log(f"pass 1 done ({time.time()-t0:.0f}s); s_in[0] {s_in[0]:.4g} s_out[-1] {s_out[-1]:.4g}; profile {profile}")

    cfgs = {"float": set()}
    kinds = args.configs.split(",")
    if "singles" in kinds:
        for s in SITES:
            cfgs[s] = {s}
    if "all" in kinds or "loo" in kinds:
        cfgs["all"] = set(SITES)
    if "loo" in kinds:
        for s in SITES:
            cfgs[f"all-{s}"] = set(SITES) - {s}
    if "groups" in kinds:
        cfgs["residual(emb,ao,z)"] = {"emb", "ao", "z"}
        cfgs["all-residual"] = set(SITES) - {"emb", "ao", "z"}
        cfgs["attn(q..o)"] = {"q", "k", "v", "rope", "qr", "kr", "s", "exp", "p", "o"}
        cfgs["ffn(gate,act,up,h)"] = {"gate", "act", "up", "h"}
        cfgs["norms(norm_a,norm_m,ceps)"] = {"norm_a", "norm_m", "ceps"}
    streams = {}
    for name, on in cfgs.items():
        x0 = xh.copy()
        if "emb" in on:
            q = np.floor(x0.astype(np.float64) / s_in[0] + 0.5)
            x0 = (np.clip(q, *I16) * s_in[0]).astype(np.float32)
        streams[name] = x0
    counts = {name: {} for name in cfgs}
    for l in range(L):
        tl = time.time()
        W = tc.layer_f32(ck, l)
        P, rep = tc.calibrate(W, stats[l], s_in[l], opt, s_x_out=s_out[l], profile=profile)
        for name, on in cfgs.items():
            streams[name] = fq_block(streams[name], W, P, rep, rope_f, rope_i, on, counts[name], s_in[l], s_out[l])
        del W, P
        rcal.log(f"L{l:02d} ({time.time()-tl:.0f}s)")
    norm_w = tc.tensor_f32(ck.refs["model.norm.weight"])
    lm_head = tc.tensor_f32(ck.refs["lm_head.weight"])
    lf = head_logprobs(streams["float"], norm_w, lm_head)
    res = {}
    for name in cfgs:
        li = head_logprobs(streams[name], norm_w, lm_head)
        m = compare(lf, li, ho_ids)
        m["clamped"] = counts[name]
        m["final_cos"] = float(tc.cos_rows(streams[name], streams["float"]).mean())
        res[name] = m
        rcal.log(f"{name:>28s}: top1 {m['top1']:.4f} KL {m['kl']:.4f} ppl {m['ppl']:.3f} cos {m['final_cos']:.5f} clamped {counts[name]}")
    summary = {"variant": args.variant, "args": vars(args), "options": opt.__dict__, "profile": profile,
               "positions": int(ho_ids[:, 1:].size), "heldout_sequences": ho_meta, "results": res,
               "seconds": time.time() - t0}
    (out / "oracle.json").write_text(tc.jdump(summary))
    rcal.log(f"done ({time.time()-t0:.0f}s) -> {out}")


if __name__ == "__main__":
    if threadpool_limits is not None:
        with threadpool_limits(limits=2):
            main()
    else:
        main()
