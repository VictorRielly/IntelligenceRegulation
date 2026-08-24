#!/usr/bin/env python3
"""m8b_smooth_experiment.py — U-PERF3 agent U (2026-08-24): SmoothQuant-class
per-channel POWER-OF-TWO rebalancing folded into adjacent weights, then the
m8b int8 calibration + verdict re-run ON THE SAME machinery/seed/windows.

Context: results/m8b_int8_calibration_wsl.json — Mistral-7B-v0.1 DOES NOT
CALIBRATE formally under TARGET_CONTRACT S2 as written (14,531 held-out
range-fact violations; chain loss 10.02 vs ref 1.84) because a few activation
channels carry 3-6000x the bulk range (emergent outliers, the >= 6.7B
LLM.int8()/SmoothQuant phenomenon). Weights-only int8 is nearly lossless
(+0.08 nats). This script tests whether EXACT function-equality rewrites of
the fp32 network rescue the calibration.

THE EXACT-FOLD IDENTITIES (all scales are powers of two, so every fold is
EXACT in fp32: multiplying/dividing an fp32 value by 2^k only moves the
exponent — the fp32 forward of the transformed network is BIT-IDENTICAL to
the reference; the proof statement binds the transformed weights and the
transform is documented preprocessing in the model identity):

  X-side (per d-channel j, s_j = 2^{se_j}, se_j >= 0):
      mlp_norm'[j]  = mlp_norm[j] / s_j
      w_gate'[:, j] = w_gate[:, j] * s_j          (w_gate is (f, d))
      w_up'[:, j]   = w_up[:, j]   * s_j
    => FFN input X'_j = X_j / s_j; gate/up pre-activations UNCHANGED.

  u/h-side (per f-channel k, t_k = 2^{te_k}, te_k >= 0):
      w_up'[k, :]   = w_up[k, :]   / t_k
      w_down'[:, k] = w_down[:, k] * t_k          (w_down is (d, f))
    => u'_k = u_k / t_k, h'_k = silu(g_k) * u'_k = h_k / t_k; z UNCHANGED.

  g-side: NO exact fold exists (SiLU is nonlinear); residual g-class tail
  risk is handled by a calibration MARGIN policy: per activation class, the
  calibrated exponent (from cal-set absmax, m125.pow2_exp_for) gets a
  configurable +margin bits of headroom (+1 = double the range, one bit of
  resolution paid).

SCALE-CHOICE POLICY (all from the CALIBRATION windows only, then frozen):
  s_j  = 2^round(log2(a_j / r_x)) clamped to >= 1 (only shrink outliers),
         a_j = per-channel absmax of X, r_x = the tensor's robust target
         (--r-quantile p999 default).
  t_k: the h-outlier factor is (u-side factor, foldable) x (silu(g)-side
       factor, NOT foldable — folding it through w_up over-shrinks u'_k
       below int8 resolution and zeroes the outlier channel). So:
         lg_tu = log2(a_u,k / r_u)         (the u-side need)
         lg_th = log2(a_h,k / r_h)         (the full h-side need)
         lg_t  = lg_tu + alpha * (lg_th - lg_tu),   --split-alpha in [0,1]
         t_k   = 2^round(lg_t) clamped to >= 1 (and optional --t-cap)
       alpha = 1.0 is the brief's start policy (t purely from h absmax);
       alpha = 0.5 splits the unfoldable silu(g) factor evenly between
       h-range headroom and u'-resolution.

Phases (--phase):
  stats  one fp32 walk of the PLAIN network over the calibration windows,
         collecting per-channel absmax (x,gate,up,a,h,z) + per-tensor
         quantile stats + per-column weight absmaxes; cached to --stats-npz.
  plan   no walk: from the cached stats, choose s/t under the given policy,
         print histograms, PREDICTED post-fold exponents (activation ranges
         predicted from folded per-channel stats; weight exponents EXACT, by
         streaming the folded tensors), predicted requant shifts, and the
         zeroed-outlier-channel diagnostic. Cheap policy iteration.
  run    the verdict: the m8b module's OWN machinery on a FoldedStore
         (weight_study -> calibrate -> margins -> silu_members ->
         run_variant A on the held-out windows -> weights-only), plus the
         plain weights-only anchor and the fp32 bit-identity check.
  all    stats (if not cached) + run.

Everything downstream of the fold is scripts/m8b_int8_calibration.py's own
code (imported from its file path, never edited): the same quantize /
floor_requant / narrow_int8 / acc_width semantics, the same Walker, the
same run_variant verdict counters, the FROZEN v2 SiLU family formula. The
fold lives in a TensorStore wrapper (FoldedStore.get), so the Walker, the
weight study and the int8 chain all see the transformed network through the
module's single access path.

Typical (WSL box):
  python3 scripts/m8b_smooth_experiment.py --phase stats
  python3 scripts/m8b_smooth_experiment.py --phase plan --split-alpha 1.0
  python3 scripts/m8b_smooth_experiment.py --phase run --split-alpha 1.0 \
      --margin-x 1 --margin-g 1 --margin-u 1 --margin-h 1 --margin-z 1 \
      --out-json results/m8b_smooth_experiment_wsl_r1.json
Smoke first (results are NOT the model's):
  python3 scripts/m8b_smooth_experiment.py --phase all --max-layers 4 \
      --stats-npz /tmp/smoke_stats.npz --out-json /tmp/smoke.json
"""

import argparse
import json
import math
import sys
import time
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

import m8b_int8_calibration as m8b   # noqa: E402  (imported, never edited)

m125 = m8b.m125    # contract-semantics primitives (quantize, requant, ...)
m125x = m8b.m125x  # frozen SiLU v2 family formula

QMAX = 127
ACT_KEYS = ("x", "gate", "up", "a", "h", "z")
DEF_CKPT = "/home/victor/models/Mistral-7B-v0.1"
DEF_TEXT = "/home/victor/models/fineweb-edu/sample_text.txt"
DEF_BASE = str(ROOT / "results" / "m8b_int8_calibration_wsl.json")


def p(line=""):
    print(line, flush=True)


def jsonable(o):
    if isinstance(o, (np.integer,)):
        return int(o)
    if isinstance(o, (np.floating,)):
        return float(o)
    if isinstance(o, np.ndarray):
        return o.tolist()
    raise TypeError(type(o))


# --------------------------------------------------------------------------
# the fold: a TensorStore wrapper (the module's single weight access path)
# --------------------------------------------------------------------------

class FoldedStore:
    """Wraps m8b.TensorStore: get() applies the exact per-channel
    power-of-two folds to mlp_norm/w_gate/w_up/w_down; every other tensor
    passes through untouched. s_exp[l] is int (d,), t_exp[l] is int (f,)."""

    def __init__(self, base, arch, s_exp, t_exp):
        self.base = base
        self.s_exp = s_exp
        self.t_exp = t_exp
        self.fold = {}
        for l in range(arch.n_layers):
            for kind in ("mlp_norm", "w_gate", "w_up", "w_down"):
                self.fold[arch.names[kind].format(l=l)] = (kind, l)

    def get(self, name):
        arr = self.base.get(name)
        if name not in self.fold:
            return arr
        kind, l = self.fold[name]
        s = np.exp2(self.s_exp[l].astype(np.float64)).astype(np.float32)
        t = np.exp2(self.t_exp[l].astype(np.float64)).astype(np.float32)
        if kind == "mlp_norm":
            return arr / s                      # (d,)
        if kind == "w_gate":
            return arr * s[None, :]             # (f, d) cols scaled up
        if kind == "w_up":
            return arr * s[None, :] / t[:, None]  # cols up, rows down
        return arr * t[None, :]                 # w_down (d, f) cols up

    def shard_paths(self):
        return self.base.shard_paths()


# --------------------------------------------------------------------------
# phase: stats (plain network, calibration windows only)
# --------------------------------------------------------------------------

def chan_absmax(v):
    flat = v.reshape(-1, v.shape[-1])
    return np.maximum(flat.max(axis=0), -flat.min(axis=0)).astype(np.float64)


def stats_pass(store, arch, walker, cal_wins, npz_path):
    p("[stats] plain fp32 walk over %d cal seqs x %d tokens, collecting "
      "per-channel absmax + per-tensor quantiles"
      % (cal_wins.shape[0], cal_wins.shape[1] - 1))
    t0 = time.time()
    chan = {}
    tens = {}

    def collect(li, dct):
        for k, v in dct.items():
            chan["%d:%s" % (li, k)] = chan_absmax(v)
            tens["%d:%s" % (li, k)] = m125.stats_of(v)

    walker.walk(cal_wins[:, :-1], collect=collect)
    p("[stats] walk done in %.0f s; streaming weight column stats" %
      (time.time() - t0))
    for l in range(arch.n_layers):
        wg = store.get(walker._n("w_gate", l))
        chan["%d:wg_col" % l] = np.maximum(wg.max(axis=0),
                                           -wg.min(axis=0)).astype(np.float64)
        del wg
        wu = store.get(walker._n("w_up", l))
        chan["%d:wu_col" % l] = np.maximum(wu.max(axis=0),
                                           -wu.min(axis=0)).astype(np.float64)
        chan["%d:wu_row" % l] = np.maximum(wu.max(axis=1),
                                           -wu.min(axis=1)).astype(np.float64)
        del wu
        wd = store.get(walker._n("w_down", l))
        chan["%d:wd_col" % l] = np.maximum(wd.max(axis=0),
                                           -wd.min(axis=0)).astype(np.float64)
        del wd
    np.savez_compressed(npz_path, meta=np.array(json.dumps(tens)), **chan)
    p("[stats] cached -> %s (%.0f s total, peak RSS %.2f GB)"
      % (npz_path, time.time() - t0, m8b.rss_gb()))


class Stats:
    def __init__(self, npz_path):
        z = np.load(npz_path)
        self.z = {k: z[k] for k in z.files if k != "meta"}
        self.tens = json.loads(str(z["meta"]))

    def chan(self, l, key):
        return self.z["%d:%s" % (l, key)]

    def tensor(self, l, key):
        return self.tens["%d:%s" % (l, key)]


# --------------------------------------------------------------------------
# the scale-choice policy
# --------------------------------------------------------------------------

def choose_scales(stats, arch, args):
    tiny = 1e-30
    s_exp, t_exp = {}, {}
    for l in range(arch.n_layers):
        rq = args.r_quantile
        ax = stats.chan(l, "x")
        rx = max(stats.tensor(l, "x")[rq], tiny)
        se = np.round(np.log2(np.maximum(ax, tiny) / rx)).astype(np.int64)
        se = np.maximum(se, 0)
        if args.s_cap is not None:
            se = np.minimum(se, args.s_cap)
        au = stats.chan(l, "up")
        ah = stats.chan(l, "h")
        ru = max(stats.tensor(l, "up")[rq], tiny)
        rh = max(stats.tensor(l, "h")[rq], tiny)
        lg_tu = np.log2(np.maximum(au, tiny) / ru)
        lg_th = np.log2(np.maximum(ah, tiny) / rh)
        lg_t = lg_tu + args.split_alpha * (lg_th - lg_tu)
        te = np.maximum(np.round(lg_t).astype(np.int64), 0)
        if args.t_cap is not None:
            te = np.minimum(te, args.t_cap)
        s_exp[l], t_exp[l] = se, te
    return s_exp, t_exp


def hist_of(vecs):
    """{exponent: channel count} aggregated over a dict of int vectors."""
    out = {}
    for v in vecs.values():
        val, cnt = np.unique(v, return_counts=True)
        for a, c in zip(val, cnt):
            out[int(a)] = out.get(int(a), 0) + int(c)
    return out


def report_scale_choice(s_exp, t_exp, arch):
    sh, th = hist_of(s_exp), hist_of(t_exp)
    p("s (X-side) exponent histogram (channels at s = 2^e over all %d "
      "layers x d=%d): %s" % (arch.n_layers, arch.d,
                              {("2^%d" % k): v for k, v in sorted(sh.items())}))
    p("t (u/h-side) exponent histogram (channels at t = 2^e over all %d "
      "layers x f=%d): %s" % (arch.n_layers, arch.f,
                              {("2^%d" % k): v for k, v in sorted(th.items())}))
    per_layer = [dict(layer=l,
                      s_hist={int(k): int(v) for k, v in
                              zip(*np.unique(s_exp[l], return_counts=True))},
                      t_hist={int(k): int(v) for k, v in
                              zip(*np.unique(t_exp[l], return_counts=True))},
                      s_max=int(s_exp[l].max()), t_max=int(t_exp[l].max()))
                 for l in range(arch.n_layers)]
    for r in per_layer:
        p("  layer %2d: s_max 2^%d (%d scaled), t_max 2^%d (%d scaled)"
          % (r["layer"], r["s_max"],
             int((s_exp[r["layer"]] > 0).sum()),
             r["t_max"], int((t_exp[r["layer"]] > 0).sum())))
    return dict(s_hist_total=sh, t_hist_total=th, per_layer=per_layer)


def zeroed_channel_diag(stats, s_exp, t_exp, arch, e_up_by_layer):
    """Channels whose folded u' absmax falls below half the eUp step
    (they quantize to 0 — their h contribution VANISHES) while their h
    carried real mass (>= the tensor's robust target)."""
    rows = []
    for l in range(arch.n_layers):
        au = stats.chan(l, "up") / np.exp2(t_exp[l].astype(np.float64))
        ah = stats.chan(l, "h")
        rh = stats.tensor(l, "h")["p999"]
        step = 2.0 ** e_up_by_layer[l]
        lost = (au < 0.5 * step) & (ah >= rh)
        if lost.any():
            rows.append(dict(layer=l, count=int(lost.sum()),
                             worst_h=float(ah[lost].max())))
    return rows


# --------------------------------------------------------------------------
# phase: plan (predictions from cached stats — no walks)
# --------------------------------------------------------------------------

def plan_phase(stats, store, arch, walker, args):
    s_exp, t_exp = choose_scales(stats, arch, args)
    p("=" * 78)
    p("PLAN — policy r=%s alpha=%.2f s_cap=%s t_cap=%s margins x/g/u/h/z "
      "= %d/%d/%d/%d/%d" % (args.r_quantile, args.split_alpha, args.s_cap,
                            args.t_cap, args.margin_x, args.margin_g,
                            args.margin_u, args.margin_h, args.margin_z))
    p("=" * 78)
    hists = report_scale_choice(s_exp, t_exp, arch)
    folded = FoldedStore(store, arch, s_exp, t_exp)
    p("%-3s %4s %4s %4s %4s %4s %4s %4s %4s %4s  %5s %5s %5s" % (
        "l", "eX'", "eG'", "eU'", "eA'", "eH'", "eZ'", "eWg'", "eWu'",
        "eWd'", "shG", "shH", "shZ"))
    e_up = {}
    rows = []
    for l in range(arch.n_layers):
        sf = np.exp2(s_exp[l].astype(np.float64))
        tf = np.exp2(t_exp[l].astype(np.float64))
        eX = m125.pow2_exp_for(float((stats.chan(l, "x") / sf).max())) \
            + args.margin_x
        eG = m125.pow2_exp_for(stats.tensor(l, "gate")["absmax"]) \
            + args.margin_g
        eU = m125.pow2_exp_for(float((stats.chan(l, "up") / tf).max())) \
            + args.margin_u
        eA = m125.pow2_exp_for(stats.tensor(l, "a")["absmax"])
        eH = m125.pow2_exp_for(float((stats.chan(l, "h") / tf).max())) \
            + args.margin_h
        eZ = m125.pow2_exp_for(stats.tensor(l, "z")["absmax"]) \
            + args.margin_z
        # exact folded weight exponents (streamed)
        eWg = m125.pow2_exp_for(
            float(np.abs(folded.get(walker._n("w_gate", l))).max()))
        eWu = m125.pow2_exp_for(
            float(np.abs(folded.get(walker._n("w_up", l))).max()))
        eWd = m125.pow2_exp_for(
            float(np.abs(folded.get(walker._n("w_down", l))).max()))
        e_up[l] = eU
        rows.append(dict(layer=l, eX=eX, eGate=eG, eUp=eU, eA=eA, eH=eH,
                         eZ=eZ, eWg=eWg, eWu=eWu, eWd=eWd))
        p("%-3d %4d %4d %4d %4d %4d %4d %4d %4d %4d  %5d %5d %5d"
          % (l, eX, eG, eU, eA, eH, eZ, eWg, eWu, eWd,
             eG - eX - eWg, eH - eA - eU, eZ - eH - eWd))
    lost = zeroed_channel_diag(stats, s_exp, t_exp, arch, e_up)
    if lost:
        p("ZEROED-OUTLIER DIAGNOSTIC (folded u' below the predicted eUp "
          "step while h carried mass — these channels' contributions "
          "VANISH from the chain):")
        for r in lost:
            p("  layer %2d: %d channels lost (worst plain-h absmax %.1f)"
              % (r["layer"], r["count"], r["worst_h"]))
    else:
        p("zeroed-outlier diagnostic: clean (no massed h channel drops "
          "below u' resolution)")
    neg = [(r["layer"], k) for r in rows for k, v in (
        ("shG", r["eGate"] - r["eX"] - r["eWg"]),
        ("shU", r["eUp"] - r["eX"] - r["eWu"]),
        ("shH", r["eH"] - r["eA"] - r["eUp"]),
        ("shZ", r["eZ"] - r["eH"] - r["eWd"])) if v < 0]
    if neg:
        p("NEGATIVE predicted requant shifts (the run phase raises the "
          "output exponent to floor them at 0): %s" % neg)
    return dict(hists=hists, predicted=rows, zeroed=lost)


# --------------------------------------------------------------------------
# margins + shift floors (applied between calibrate() and the verdict)
# --------------------------------------------------------------------------

def apply_margins(scales, args):
    fixups = []
    for sc in scales:
        sc["eX"] += args.margin_x
        sc["eGate"] += args.margin_g
        sc["eUp"] += args.margin_u
        sc["eH"] += args.margin_h
        sc["eZ"] += args.margin_z
        adj = {}
        # requant shifts must be >= 0 (m125.floor_requant asserts);
        # fix in chain order — raising eH feeds the eZ check.
        for out, lo in (("eGate", sc["eX"] + sc["eWg"]),
                        ("eUp", sc["eX"] + sc["eWu"]),
                        ("eH", sc["eA"] + sc["eUp"]),
                        ("eZ", sc["eH"] + sc["eWd"])):
            if sc[out] < lo:
                adj[out] = dict(frm=sc[out], to=lo)
                sc[out] = lo
        if adj:
            fixups.append(dict(layer=sc["layer"], **adj))
    return fixups


# --------------------------------------------------------------------------
# phase: run (the verdict — the module's own machinery on the FoldedStore)
# --------------------------------------------------------------------------

def run_phase(stats, store, arch, walker_plain, cal, val, args, base):
    t0 = time.time()
    s_exp, t_exp = choose_scales(stats, arch, args)
    hists = report_scale_choice(s_exp, t_exp, arch)
    folded = FoldedStore(store, arch, s_exp, t_exp)
    walker = m8b.Walker(folded, arch, args.t)

    # fp32 bit-identity of the folds (the exactness claim, measured).
    # In-process (smoke) it is a hard assert; against the recorded
    # baseline JSON it additionally tests cross-run BLAS determinism, so
    # a mismatch there is a warning with the diff printed.
    ref_fold = None
    if args.max_layers:
        ref_plain = walker_plain.loss(val)
        src = "recomputed plain walk (truncated stack)"
    else:
        ref_plain = base["int8_chain"]["loss_ref"]
        src = "baseline JSON loss_ref"
    if not args.skip_ref:
        ref_fold = walker.loss(val)
        p("fp32 EXACTNESS: transformed ref loss %.10f vs plain %.10f "
          "(%s) -> %s"
          % (ref_fold, ref_plain, src,
             "BIT-IDENTICAL" if ref_fold == ref_plain else
             "DIFF %.3e ** check fold exactness / BLAS determinism **"
             % (ref_fold - ref_plain)))
        if args.max_layers:
            assert ref_fold == ref_plain, \
                "power-of-two fold must be fp32-exact in-process"

    wrows = m8b.weight_study(folded, arch, walker)
    scales = m8b.calibrate(walker, cal, wrows, arch)
    fixups = apply_margins(scales, args)
    p("margins applied: x/g/u/h/z = %d/%d/%d/%d/%d; shift-floor fixups: %s"
      % (args.margin_x, args.margin_g, args.margin_u, args.margin_h,
         args.margin_z, fixups if fixups else "none"))
    members = m8b.silu_members(scales)
    p()
    fresh = m8b.report_members(members)

    n_pos = int(val[:, :-1].size)
    p()
    p("=" * 78)
    p("VERDICT PASS — int8 chain on HELD-OUT data (%d seq x %d tokens), "
      "transformed network" % (val.shape[0], args.t))
    p("=" * 78)
    A = m8b.run_variant(walker, scales, members, val, "floor",
                        "A floor/per-tensor (folded)", arch, verbose=True)
    p("-> violations %d of %d positions x 5 facts; loss %.4f (ref %.4f, "
      "delta %+.4f)" % (A["total_viol"], n_pos, A["loss"], ref_plain,
                        A["loss"] - ref_plain))
    loss_wonly_f = walker.loss(val, ffn_override=m8b.make_wonly_ffn(scales))
    p("weights-only (FOLDED weights, fp acts): loss %.4f (%+.4f) — the "
      "migration cost on the weight side"
      % (loss_wonly_f, loss_wonly_f - ref_plain))

    anchor = None
    if not args.skip_anchor and not args.max_layers:
        base_scales = base["calibration"]
        anchor = walker_plain.loss(
            val, ffn_override=m8b.make_wonly_ffn(base_scales))
        want = base["int8_chain"]["weights_only"]["loss"]
        p("plain weights-only ANCHOR: %.6f (baseline recorded %.6f, diff "
          "%.1e)" % (anchor, want, anchor - want))

    calibrates = (A["total_viol"] == 0)
    p()
    p("=" * 78)
    p("VERDICT (transformed network, same criteria as the baseline run)")
    p("=" * 78)
    p("range facts on held-out data: %s (%d violations, variant A)"
      % ("HOLD" if calibrates else "FAIL", A["total_viol"]))
    if fresh:
        p("SiLU family: %d NEW member(s) %s — memo W-6 ruling needed"
          % (len(fresh), [k for k, _ in fresh]))
    else:
        p("SiLU family: every calibrated member is already frozen")
    p("verdict: the TRANSFORMED checkpoint %s formally; chain %+.4f nats "
      "(baseline chain was %+.4f); folded weights-only %+.4f (baseline "
      "%+.4f)" % ("CALIBRATES" if calibrates else "DOES NOT CALIBRATE",
                  A["loss"] - ref_plain,
                  base["verdict"]["loss_delta_nats"]["A"],
                  loss_wonly_f - ref_plain,
                  base["verdict"]["loss_delta_nats"]["weights_only"]))

    base_pl = {pl_i: v["viol"] for pl_i, v in
               enumerate(base["int8_chain"]["variants"][0]["per_layer"])}
    e_up = {sc["layer"]: sc["eUp"] for sc in scales}
    report = dict(
        experiment="m8b_smooth_experiment (SmoothQuant-class power-of-two "
                   "per-channel rebalancing, exact fp32 folds)",
        checkpoint=str(args.ckpt), seed=args.seed,
        dims=dict(layers=arch.n_layers, d=arch.d, f=arch.f, t=args.t),
        truncated=bool(args.max_layers),
        policy=dict(r_quantile=args.r_quantile,
                    split_alpha=args.split_alpha,
                    s_cap=args.s_cap, t_cap=args.t_cap,
                    margins=dict(x=args.margin_x, g=args.margin_g,
                                 u=args.margin_u, h=args.margin_h,
                                 z=args.margin_z)),
        fp32_exactness=dict(transformed_ref_loss=ref_fold,
                            plain_ref_loss=ref_plain, source=src,
                            bit_identical=(bool(ref_fold == ref_plain)
                                           if ref_fold is not None
                                           else None)),
        scale_hists=hists,
        weights=wrows,
        calibration=scales,
        shift_fixups=fixups,
        silu_members={"%d,%d" % k: dict(digest=dg, frozen=fr)
                      for k, (t, dg, fr) in members.items()},
        int8_chain=dict(loss_ref=ref_plain, positions=n_pos, variants=[A],
                        weights_only_folded=dict(
                            loss=loss_wonly_f,
                            delta=loss_wonly_f - ref_plain),
                        weights_only_plain_anchor=anchor),
        per_layer_viol_before_after=[
            dict(layer=li, before=base_pl.get(li),
                 after=A["per_layer"][li]["viol"],
                 rel_ffn_err_before=(
                     base["int8_chain"]["variants"][0]["per_layer"][li]
                     ["rel_ffn_err"] if li in base_pl else None),
                 rel_ffn_err_after=A["per_layer"][li]["rel_ffn_err"])
            for li in range(arch.n_layers)],
        zeroed_channel_diag=zeroed_channel_diag(stats, s_exp, t_exp, arch,
                                                e_up),
        verdict=dict(
            calibrates_formally=calibrates,
            range_violations=dict(A=A["total_viol"],
                                  baseline=base["verdict"]
                                  ["range_violations"]["A"]),
            silu_new_members=["%d,%d" % k for k, _ in fresh],
            loss_ref=ref_plain,
            loss_delta_nats=dict(
                A=A["loss"] - ref_plain,
                A_baseline=base["verdict"]["loss_delta_nats"]["A"],
                weights_only_folded=loss_wonly_f - ref_plain,
                weights_only_baseline=base["verdict"]["loss_delta_nats"]
                ["weights_only"])),
        wall_s=time.time() - t0, peak_rss_gb=m8b.rss_gb())
    out = Path(args.out_json)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, indent=1, default=jsonable))
    p("JSON -> %s" % out)
    p("wall %.0f s, peak RSS %.2f GB" % (report["wall_s"],
                                         report["peak_rss_gb"]))


# --------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ckpt", default=DEF_CKPT)
    ap.add_argument("--arch", default="hf", choices=("hf", "frugal"))
    ap.add_argument("--tokens", default=None)
    ap.add_argument("--text", default=DEF_TEXT)
    ap.add_argument("--t", type=int, default=512)
    ap.add_argument("--cal-seqs", type=int, default=8)
    ap.add_argument("--val-seqs", type=int, default=8)
    ap.add_argument("--seed", type=int, default=1337)
    ap.add_argument("--max-layers", type=int, default=None,
                    help="truncate the stack (SMOKE ONLY)")
    ap.add_argument("--phase", default="all",
                    choices=("stats", "plan", "run", "all"))
    ap.add_argument("--stats-npz",
                    default=str(ROOT / "results" / "m8b_smooth_stats.npz"),
                    help="cache for the phase-1 per-channel stats "
                         "(an intermediate, not a deliverable)")
    ap.add_argument("--baseline-json", default=DEF_BASE)
    ap.add_argument("--out-json",
                    default=str(ROOT / "results" /
                                "m8b_smooth_experiment.json"))
    ap.add_argument("--r-quantile", default="p999",
                    choices=("p999", "p9999"))
    ap.add_argument("--split-alpha", type=float, default=1.0,
                    help="1.0 = t purely from h absmax (the brief's start "
                         "policy); 0.5 splits the unfoldable silu(g) "
                         "factor between h-range and u'-resolution")
    ap.add_argument("--s-cap", type=int, default=None)
    ap.add_argument("--t-cap", type=int, default=None)
    ap.add_argument("--margin-x", type=int, default=0)
    ap.add_argument("--margin-g", type=int, default=0)
    ap.add_argument("--margin-u", type=int, default=0)
    ap.add_argument("--margin-h", type=int, default=0)
    ap.add_argument("--margin-z", type=int, default=0)
    ap.add_argument("--skip-anchor", action="store_true")
    ap.add_argument("--skip-ref", action="store_true",
                    help="skip the transformed fp32 ref-loss walk "
                         "(iteration rounds; exactness already proven)")
    args = ap.parse_args()

    arch = m8b.make_arch(args.arch, args.ckpt)
    if args.max_layers:
        arch.n_layers = min(arch.n_layers, args.max_layers)
        p("** TRUNCATED to %d layers — SMOKE, results are not the "
          "model's **" % arch.n_layers)
    store = m8b.TensorStore(args.ckpt)
    walker = m8b.Walker(store, arch, args.t)
    p("m8b_smooth_experiment — %s (%d layers, d %d, f %d); phase %s"
      % (arch.tag, arch.n_layers, arch.d, arch.f, args.phase))

    npz = Path(args.stats_npz)
    if args.phase in ("stats", "all") and (args.phase == "stats"
                                           or not npz.exists()):
        toks = m8b.load_token_stream(args, args.ckpt)
        cal, _ = m8b.token_batches(toks, args.seed, args.cal_seqs,
                                   args.val_seqs, args.t)
        stats_pass(store, arch, walker, cal, npz)
        if args.phase == "stats":
            return
    assert npz.exists(), "run --phase stats first (no cache at %s)" % npz
    stats = Stats(npz)

    if args.phase == "plan":
        plan_phase(stats, store, arch, walker, args)
        p("peak RSS %.2f GB" % m8b.rss_gb())
        return

    base = json.loads(Path(args.baseline_json).read_text())
    toks = m8b.load_token_stream(args, args.ckpt)
    cal, val = m8b.token_batches(toks, args.seed, args.cal_seqs,
                                 args.val_seqs, args.t)
    run_phase(stats, store, arch, walker, cal, val, args, base)


if __name__ == "__main__":
    main()
