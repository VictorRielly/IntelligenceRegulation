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

--------------------------------------------------------------------------
AGENT V EXTENSION (2026-08-24, --phase blite) — the (b)-lite pricing
experiment: per-column POWER-OF-TWO requant scales at the u/h/z sites
(+ optionally per-column w_down weight scales) and widened SiLU classes
at named layers, ON TOP of the same machinery. Everything stays exact
integers (float64-carried, all values << 2^53); the per-tensor path with
every extension off reduces BIT-EXACTLY to the m8b module's own chain
(--equiv-check asserts it in-process against m8b.run_variant).

Semantics added (each a statement/engine surface the report counts):
  ucols   per-column eUp_k (f-vector): the up requant shift becomes the
          public per-column vector sh_u_k = eUp_k - eX - eWu (requant
          AFTER the accumulator, per OUTPUT column — no alignment cost).
  hcols   per-column eH_k: sh_h_k = eH_k - eA - eUp_k (the Hadamard is
          elementwise — no alignment cost at this site either).
  zcols   per-column eZ_j (d-vector): sh_z_j = eZ_j - P_base, requant of
          the down accumulator per OUTPUT column.
  wdcols  per-column w_down scales ecol_k. THE ONE ALIGNMENT SITE: down
          products sit at per-column scales eH_k + ecol_k, so the sum
          needs public align exponents a_k = (eH_k + ecol_k) - P_base,
          P_base = min_k; the sim carries Wd8 * 2^a_k exactly and reports
          the honest accumulator bound 127 * 127 * sum_k 2^a_k (the
          engine's tier accounting) per layer.
  a16=L / g16=L   widened SiLU classes at the listed layers (or 'all'):
          a16 = int16 table OUTPUT (Qa 32767, eA16 = ceil(log2(a/32767)))
          -- the Hadamard product class widens to <= 32767*127 (2^22);
          g16 = int16 table DOMAIN (gate range fact at Qg 32767) — a
          65536-row table in the engine. Both use the v2 rounding formula
          (round_half_up) with the wider clamp — a NEW family, recorded
          as (eG, eA, in_bits, out_bits) in the inventory.

Per-tensor calibration rows are NOT re-walked: with t = 0 (asserted) and
the s-fold exactly invariant on gate/up/a/h/z, every exponent derives
EXACTLY from the baseline record + the cached per-channel stats (+ a
stream over the folded wg/wu); the smoke validates the derivation
against a real m8b.calibrate walk on the folded store, and the full run
cross-checks derived == baseline on every fold-invariant row.

Typical:
  python3 scripts/m8b_smooth_experiment.py --phase blite --t-cap 0 \
      --s-cap 3 --stats-npz <cal stats npz> \
      --bl-variant "name=percol,ucols,hcols,zcols,wdcols" \
      --bl-variant "name=wide,ucols,hcols,zcols,wdcols,a16=all,g16=0;1;2;31" \
      --bl-out results/m8b_blite_experiment_wsl.json
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
# AGENT V — the (b)-lite machinery (per-column scales + widened SiLU)
# --------------------------------------------------------------------------

Q8 = 127
Q16 = 32767


def pow2_exp_q(absmax, q):
    """Smallest e with absmax <= q * 2^e (the m125 convention at width q)."""
    if absmax == 0:
        return -30
    return int(math.ceil(math.log2(absmax / q)))


def parse_bl_spec(spec):
    """'name=P1,ucols,hcols,zcols,wdcols,a16=all,g16=0;1;31,mx=2,mg=1,...'
    -> option dict. Layer lists use ';' separators inside one token."""
    opt = dict(name="v", ucols=False, hcols=False, zcols=False,
               wdcols=False, a16=None, g16=None,
               mx=2, mg=1, mu=1, mh=1, mz=1)
    for tok in spec.split(","):
        tok = tok.strip()
        if not tok:
            continue
        if "=" in tok:
            k, v = tok.split("=", 1)
            if k == "name":
                opt["name"] = v
            elif k in ("a16", "g16"):
                opt[k] = "all" if v == "all" else \
                    sorted(int(x) for x in v.split(";") if x != "")
            elif k in ("mx", "mg", "mu", "mh", "mz"):
                opt[k] = int(v)
            else:
                raise SystemExit("unknown bl-variant key %r" % k)
        elif tok in ("ucols", "hcols", "zcols", "wdcols"):
            opt[tok] = True
        else:
            raise SystemExit("unknown bl-variant token %r" % tok)
    return opt


def wide_layers(sel, n_layers):
    if sel is None:
        return set()
    if sel == "all":
        return set(range(n_layers))
    return set(l for l in sel if l < n_layers)


def silu_wide(yg, eg, ea, qa):
    """The v2 family rounding formula (round_half_up) at wider clamp:
    a = clamp(floor(silu(yg * 2^eg) / 2^ea + 0.5), -qa, qa). A NEW
    family (int16 domain and/or range), recorded in the inventory."""
    x = yg.astype(np.float64) * (2.0 ** eg)
    y = x / (1.0 + np.exp(-x))
    return np.clip(np.floor(y / (2.0 ** ea) + 0.5), -qa, qa)


def narrow_q(y, q):
    """m125.narrow_int8 generalized to width q (identical at q = 127)."""
    viol = int(np.count_nonzero(np.abs(y) > q))
    return np.clip(y, -q, q), viol


def derive_scales_blite(stats, base, s_exp, t_exp, folded, walker, arch):
    """Per-tensor scale rows (m8b.calibrate's keys), derived EXACTLY —
    t must be 0 (asserted); the s-fold is exactly invariant on
    gate/up/a/h/z (measured bit-identity, agent U), so those rows come
    from the baseline record; eX from the cached per-channel stats
    (exact pow2 division); eWg/eWu by streaming the folded tensors when
    s != 0. Cross-check: every fold-invariant exponent must equal the
    baseline record's (asserted)."""
    rows = []
    s_on = any(int(s_exp[l].max()) > 0 for l in s_exp)
    for l in range(arch.n_layers):
        b = base["calibration"][l]
        assert int(t_exp[l].max()) == 0, "blite requires --t-cap 0"
        ax = stats.chan(l, "x") / np.exp2(s_exp[l].astype(np.float64))
        eX = m125.pow2_exp_for(float(ax.max()))
        if not int(s_exp[l].max()):
            assert eX == b["eX"], \
                "layer %d: derived eX %d != baseline %d (stats npz is " \
                "not the baseline cal windows?)" % (l, eX, b["eX"])
        # fold-invariant cross-checks (npz absmax vs baseline stats)
        for key, ek in (("up", "eUp"), ("h", "eH")):
            der = m125.pow2_exp_for(float(stats.chan(l, key).max()))
            assert der == b[ek], \
                "layer %d: npz-derived %s %d != baseline %d" % (
                    l, ek, der, b[ek])
        if s_on and int(s_exp[l].max()):
            eWg = m125.pow2_exp_for(
                float(np.abs(folded.get(walker._n("w_gate", l))).max()))
            eWu = m125.pow2_exp_for(
                float(np.abs(folded.get(walker._n("w_up", l))).max()))
        else:
            eWg, eWu = b["eWg"], b["eWu"]
        rows.append(dict(layer=l, stats=b["stats"], eX=eX,
                         eGate=b["eGate"], eUp=b["eUp"], eA=b["eA"],
                         eH=b["eH"], eZ=b["eZ"], eWg=eWg, eWu=eWu,
                         eWd=b["eWd"]))
    return rows


def blite_percol(stats, rows, arch, opt, s_exp):
    """Per-layer per-column scale plan + engine accounting. Returns
    (pc list, accounting list). All vectors int64; every shift >= 0 by
    the same floors the module's apply_margins enforces (recorded as
    fixups)."""
    a16 = wide_layers(opt["a16"], arch.n_layers)
    g16 = wide_layers(opt["g16"], arch.n_layers)
    pc, acct = [], []
    for l in range(arch.n_layers):
        r = rows[l]
        st = r["stats"]
        fix = {}
        eX = r["eX"] + opt["mx"]
        eWg, eWu, eWd = r["eWg"], r["eWu"], r["eWd"]
        # gate (per-tensor always; wide domain at g16 layers)
        Qg = Q16 if l in g16 else Q8
        eG = pow2_exp_q(st["gate"]["absmax"], Qg) + opt["mg"]
        if eG < eX + eWg:
            fix["eGate"] = dict(frm=eG, to=eX + eWg)
            eG = eX + eWg
        # a (table output; no margin — the table clamp IS the range fact)
        Qa = Q16 if (l in a16 or l in g16) else Q8
        eA = pow2_exp_q(st["a"]["absmax"], Qa)
        # u
        au = stats.chan(l, "up")
        if opt["ucols"]:
            eU = np.array([m125.pow2_exp_for(v) for v in au],
                          dtype=np.int64) + opt["mu"]
        else:
            eU = np.full(arch.f, r["eUp"] + opt["mu"], dtype=np.int64)
        n_fix_u = int((eU < eX + eWu).sum())
        if n_fix_u:
            fix["eUp_cols"] = n_fix_u
        eU = np.maximum(eU, eX + eWu)
        # h
        ah = stats.chan(l, "h")
        if opt["hcols"]:
            eH = np.array([m125.pow2_exp_for(v) for v in ah],
                          dtype=np.int64) + opt["mh"]
        else:
            eH = np.full(arch.f, r["eH"] + opt["mh"], dtype=np.int64)
        n_fix_h = int((eH < eA + eU).sum())
        if n_fix_h:
            fix["eH_cols"] = n_fix_h
        eH = np.maximum(eH, eA + eU)
        # w_down columns
        awd = stats.chan(l, "wd_col")
        if opt["wdcols"]:
            ecol = np.array([m125.pow2_exp_for(v) for v in awd],
                            dtype=np.int64)
        else:
            ecol = np.full(arch.f, eWd, dtype=np.int64)
        p = eH + ecol
        p_base = int(p.min())
        align = p - p_base
        # z
        az = stats.chan(l, "z")
        if opt["zcols"]:
            eZ = np.array([m125.pow2_exp_for(v) for v in az],
                          dtype=np.int64) + opt["mz"]
        else:
            eZ = np.full(arch.d, r["eZ"] + opt["mz"], dtype=np.int64)
        n_fix_z = int((eZ < p_base).sum())
        if n_fix_z:
            fix["eZ_cols"] = n_fix_z
        eZ = np.maximum(eZ, p_base)
        sh_g = eG - eX - eWg
        sh_u = eU - eX - eWu
        sh_h = eH - eA - eU
        sh_z = eZ - p_base
        # engine accounting: honest worst-case down-acc bound with the
        # aligned columns; alignment tier count at 8-bit windows
        sum2a = float(np.exp2(align.astype(np.float64)).sum())
        bound_down = Q8 * Q8 * sum2a
        acc_bits_down = int(math.floor(math.log2(bound_down))) + 2
        acct.append(dict(
            layer=l, sh_g=int(sh_g),
            sh_u_max=int(sh_u.max()), sh_h_max=int(sh_h.max()),
            sh_z_max=int(sh_z.max()), align_max=int(align.max()),
            sum_2a=sum2a, acc_bits_down=acc_bits_down,
            tiers_at_8=int(math.ceil(max(int(align.max()), 1) / 8.0)),
            n_align_gt0=int((align > 0).sum()),
            fixups=fix))
        pc.append(dict(
            layer=l, g16=(l in g16), a16=(Qa == Q16), Qg=Qg, Qa=Qa,
            eX=eX, eWg=eWg, eWu=eWu, eG=eG, eA=eA,
            eU=eU, eH=eH, ecol=ecol, align=align, p_base=p_base,
            eZ=eZ, sh_g=sh_g, sh_u=sh_u, sh_h=sh_h, sh_z=sh_z,
            m_gu=arch.d * Q8 * Q8, bound_down=bound_down))
    return pc, acct


def make_blite_ffn(pc, members, acc_track, viol_track, err_track):
    """The b-lite chain: exact integers in float64 BLAS (worst value
    2^46 << 2^53 — asserted on the first call), floor requant with
    vector shifts (m125.floor_requant's own vector path)."""
    checked = [False]

    def ffn(li, x, lw):
        c = pc[li]
        B, T, C = x.shape
        f = lw["w_up"].shape[0]
        Wg, _ = m125.quantize(lw["w_gate"].astype(np.float64), c["eWg"])
        Wu, _ = m125.quantize(lw["w_up"].astype(np.float64), c["eWu"])
        stepc = np.exp2(c["ecol"].astype(np.float64))
        Wd = np.round(lw["w_down"].astype(np.float64) / stepc[None, :])
        Wd = np.clip(Wd, -Q8, Q8)
        Wd *= np.exp2(c["align"].astype(np.float64))[None, :]  # aligned
        tab = None
        if not (c["a16"] or c["g16"]):
            tab = members[(c["eG"], c["eA"])][0].astype(np.float64)
        z_out = np.empty((B, T, C), dtype=np.float32)
        for b in range(B):
            xf = x[b].astype(np.float64)
            xq, xclip = m125.quantize(xf, c["eX"])
            viol_track[li]["X_clip"] += xclip
            acc_g = xq @ Wg.T
            acc_u = xq @ Wu.T
            acc_track[li]["gateup"] = max(acc_track[li]["gateup"],
                                          float(np.abs(acc_g).max()),
                                          float(np.abs(acc_u).max()))
            yg, vg = narrow_q(m125.floor_requant(acc_g, c["sh_g"]),
                              c["Qg"])
            yu, vu = narrow_q(
                m125.floor_requant(acc_u, c["sh_u"][None, :]), Q8)
            viol_track[li]["gate_range"] += vg
            viol_track[li]["up_range"] += vu
            if tab is not None:
                aq = tab[(yg.astype(np.int64) + 128)]
            else:
                aq = silu_wide(yg, c["eG"], c["eA"], c["Qa"])
            hq = aq * yu
            acc_track[li]["had"] = max(acc_track[li]["had"],
                                       float(np.abs(hq).max()))
            yh, vh = narrow_q(
                m125.floor_requant(hq, c["sh_h"][None, :]), Q8)
            viol_track[li]["h_range"] += vh
            acc_d = yh @ Wd.T
            acc_track[li]["down"] = max(acc_track[li]["down"],
                                        float(np.abs(acc_d).max()))
            yz, vz = narrow_q(
                m125.floor_requant(acc_d, c["sh_z"][None, :]), Q8)
            viol_track[li]["z_range"] += vz
            z_out[b] = (yz * np.exp2(c["eZ"].astype(np.float64))[None, :]
                        ).astype(np.float32)
            if not checked[0]:
                checked[0] = True
                for nm, v in (("acc_d", acc_d), ("hq", hq), ("yz", yz)):
                    assert float(np.abs(v).max()) < 2.0 ** 52, nm
                    assert np.all(v == np.floor(v)), \
                        "%s not integral — exactness broken" % nm
        # matched-input fp reference on the SAME x (module's formula)
        flat = x.reshape(B * T, C)
        gate = flat @ lw["w_gate"].T
        zf = ((gate / (1.0 + np.exp(-gate)) * (flat @ lw["w_up"].T))
              @ lw["w_down"].T).astype(np.float64)
        zq = z_out.reshape(B * T, -1).astype(np.float64)
        num = float(np.sqrt(((zf - zq) ** 2).mean()))
        den = float(np.sqrt((zf ** 2).mean()))
        err_track[li].append(num / den if den else 0.0)
        return z_out

    return ffn


def make_blite_wonly(pc):
    """Weights-only attribution under the b-lite weight plan (per-tensor
    wg/wu, per-column wd when enabled), fp activations."""

    def ffn(li, x, lw):
        c = pc[li]
        B, T, C = x.shape
        flat = x.reshape(B * T, C).astype(np.float64)
        qg, _ = m125.quantize(lw["w_gate"].astype(np.float64), c["eWg"])
        qu, _ = m125.quantize(lw["w_up"].astype(np.float64), c["eWu"])
        stepc = np.exp2(c["ecol"].astype(np.float64))
        qd = np.clip(np.round(lw["w_down"].astype(np.float64)
                              / stepc[None, :]), -Q8, Q8) * stepc[None, :]
        dg = qg * (2.0 ** c["eWg"])
        du = qu * (2.0 ** c["eWu"])
        gate = flat @ dg.T
        z = ((gate / (1.0 + np.exp(-gate)) * (flat @ du.T)) @ qd.T)
        return z.astype(np.float32).reshape(B, T, C)

    return ffn


def blite_members(pc):
    """Frozen-family members for the a8 layers (module machinery) + the
    wide-class inventory for the a16/g16 layers."""
    members, wide = {}, []
    for c in pc:
        if c["a16"] or c["g16"]:
            wide.append(dict(layer=c["layer"],
                             in_bits=16 if c["g16"] else 8,
                             out_bits=16 if c["a16"] else 8,
                             eG=int(c["eG"]), eA=int(c["eA"])))
            continue
        key = (c["eG"], c["eA"])
        if key not in members:
            t = m125x.silu_v2_generate(*key)
            dg = m125x.silu_v2_digest(key[0], key[1], t)
            members[key] = (t, dg, m125x.SILU_V2_PINS.get(key) == dg)
    return members, wide


def agg_hist(vecs):
    out = {}
    for v in vecs:
        val, cnt = np.unique(v, return_counts=True)
        for a, c in zip(val, cnt):
            out[int(a)] = out.get(int(a), 0) + int(c)
    return out


def run_blite_variant(walker, pc, acct, val_wins, label, arch,
                      verbose=True):
    L = arch.n_layers
    acc_track = [dict(gateup=0.0, had=0.0, down=0.0) for _ in range(L)]
    viol_track = [dict(X_clip=0, gate_range=0, up_range=0, h_range=0,
                       z_range=0) for _ in range(L)]
    err_track = [[] for _ in range(L)]
    members, wide = blite_members(pc)
    ffn = make_blite_ffn(pc, members, acc_track, viol_track, err_track)
    loss = walker.loss(val_wins, ffn_override=ffn)
    total_viol = 0
    cls_tot = dict(X_clip=0, gate_range=0, up_range=0, h_range=0,
                   z_range=0)
    if verbose:
        p("%-6s %12s %14s %10s %30s %10s" % (
            "layer", "max|acc_gu|", "max|acc_dn|", "max|had|",
            "violations X/g/u/h/z (held-out)", "relFFNerr"))
    for li in range(L):
        v = viol_track[li]
        total_viol += sum(v.values())
        for k in cls_tot:
            cls_tot[k] += v[k]
        if verbose:
            p("%-6d %12.0f %14.0f %10.0f %30s %10.4f"
              % (li, acc_track[li]["gateup"], acc_track[li]["down"],
                 acc_track[li]["had"],
                 "X:%d g:%d u:%d h:%d z:%d" % (
                     v["X_clip"], v["gate_range"], v["up_range"],
                     v["h_range"], v["z_range"]),
                 float(np.mean(err_track[li]))))
        assert acc_track[li]["gateup"] <= pc[li]["m_gu"]
        assert acc_track[li]["down"] <= pc[li]["bound_down"], \
            "layer %d: down acc %e over the honest aligned bound %e" % (
                li, acc_track[li]["down"], pc[li]["bound_down"])
    return dict(label=label, loss=loss, total_viol=total_viol,
                viol_by_class=cls_tot,
                per_layer=[dict(acc=acc_track[li], viol=viol_track[li],
                                rel_ffn_err=float(np.mean(err_track[li])),
                                acct=acct[li])
                           for li in range(L)],
                silu_wide_inventory=wide,
                silu_members={"%d,%d" % k: dict(digest=dg, frozen=fr)
                              for k, (t, dg, fr) in members.items()})


def blite_phase(stats, store, arch, walker_plain, cal, val, args, base):
    t0 = time.time()
    s_exp, t_exp = choose_scales(stats, arch, args)
    for l in range(arch.n_layers):
        assert int(t_exp[l].max()) == 0, \
            "--phase blite requires --t-cap 0 (per-column scales replace " \
            "the t-fold)"
    report_scale_choice(s_exp, t_exp, arch)
    folded = FoldedStore(store, arch, s_exp, t_exp)
    walker = m8b.Walker(folded, arch, args.t)
    rows = derive_scales_blite(stats, base, s_exp, t_exp, folded, walker,
                               arch)
    p("[blite] per-tensor rows derived exactly (t = 0; fold-invariant "
      "rows == baseline record, asserted)")

    if args.validate_calibrate:
        p("[blite] VALIDATION: m8b.calibrate walk on the folded store "
          "(%d layers) vs the derived rows" % arch.n_layers)
        wrows = [dict(layer=r["layer"], tensor=t_,
                      exp={"w_gate": r["eWg"], "w_up": r["eWu"],
                           "w_down": r["eWd"]}[t_])
                 for r in rows for t_ in ("w_gate", "w_up", "w_down")]
        walked = m8b.calibrate(walker, cal, wrows, arch)
        for r, w in zip(rows, walked):
            for k in ("eX", "eGate", "eUp", "eA", "eH", "eZ"):
                assert r[k] == w[k], "derived %s mismatch at layer %d: " \
                    "%d != %d" % (k, r["layer"], r[k], w[k])
        p("[blite] VALIDATION OK: every derived exponent equals the "
          "module's own calibrate walk")

    if args.max_layers:
        ref = walker_plain.loss(val)
        src = "recomputed plain walk (truncated stack)"
    else:
        ref = base["int8_chain"]["loss_ref"]
        src = "baseline JSON loss_ref"
    n_pos = int(val[:, :-1].size)
    out_vars = []
    for spec in args.bl_variant:
        opt = parse_bl_spec(spec)
        pc, acct = blite_percol(stats, rows, arch, opt, s_exp)
        p()
        p("=" * 78)
        p("BLITE VARIANT %s — %s; margins x/g/u/h/z = %d/%d/%d/%d/%d; "
          "a16 %s g16 %s" % (
              opt["name"],
              "/".join(k for k in ("ucols", "hcols", "zcols", "wdcols")
                       if opt[k]) or "per-tensor",
              opt["mx"], opt["mg"], opt["mu"], opt["mh"], opt["mz"],
              opt["a16"], opt["g16"]))
        p("=" * 78)
        if args.equiv_check and not any(
                (opt["ucols"], opt["hcols"], opt["zcols"], opt["wdcols"],
                 opt["a16"], opt["g16"])):
            # the module's own path on the SAME final per-tensor scales
            mod_scales = []
            for c, r in zip(pc, rows):
                mod_scales.append(dict(
                    layer=r["layer"], eX=c["eX"], eGate=c["eG"],
                    eUp=int(c["eU"][0]), eA=c["eA"], eH=int(c["eH"][0]),
                    eZ=int(c["eZ"][0]), eWg=c["eWg"], eWu=c["eWu"],
                    eWd=r["eWd"]))
            mem = m8b.silu_members(mod_scales)
            M = m8b.run_variant(walker, mod_scales, mem, val, "floor",
                                "module equiv", arch, verbose=False)
            V = run_blite_variant(walker, pc, acct, val, opt["name"],
                                  arch, verbose=False)
            assert V["loss"] == M["loss"], \
                "EQUIV FAIL: blite loss %.10f != module %.10f" % (
                    V["loss"], M["loss"])
            assert V["total_viol"] == M["total_viol"], "EQUIV FAIL viol"
            for a_, b_ in zip(V["per_layer"], M["per_layer"]):
                assert a_["viol"] == b_["viol"], "EQUIV FAIL per-layer"
            p("EQUIV CHECK OK: blite per-tensor path == m8b.run_variant "
              "bit-exactly (loss %.10f, %d violations)"
              % (V["loss"], V["total_viol"]))
        else:
            V = run_blite_variant(walker, pc, acct, val, opt["name"],
                                  arch)
        p("-> %s: violations %d of %d positions x 5 facts %s; loss %.4f "
          "(ref %.4f, delta %+.4f)"
          % (opt["name"], V["total_viol"], n_pos,
             dict(V["viol_by_class"]), V["loss"], ref, V["loss"] - ref))
        wonly = None
        if args.bl_wonly:
            wonly = walker.loss(val, ffn_override=make_blite_wonly(pc))
            p("   weights-only (b-lite weight plan): %.4f (%+.4f)"
              % (wonly, wonly - ref))
        hists = dict(
            sh_u=agg_hist([c["sh_u"] for c in pc]),
            sh_h=agg_hist([c["sh_h"] for c in pc]),
            sh_z=agg_hist([c["sh_z"] for c in pc]),
            align=agg_hist([c["align"] for c in pc]))
        eng = dict(
            max_sh_u=max(a["sh_u_max"] for a in acct),
            max_sh_h=max(a["sh_h_max"] for a in acct),
            max_sh_z=max(a["sh_z_max"] for a in acct),
            max_align=max(a["align_max"] for a in acct),
            worst_acc_bits_down=max(a["acc_bits_down"] for a in acct),
            layers_over_31bit_acc=[a["layer"] for a in acct
                                   if a["acc_bits_down"] > 31],
            layers_multi_tier=[(a["layer"], a["tiers_at_8"])
                               for a in acct if a["tiers_at_8"] > 1],
            rem_bits_needed=max(
                max(a["sh_u_max"] for a in acct),
                max(a["sh_h_max"] for a in acct),
                max(a["sh_z_max"] for a in acct),
                max(a["sh_g"] for a in acct)))
        p("   engine accounting: max sh u/h/z = %d/%d/%d, max align %d, "
          "worst honest down-acc bits %d, layers over 31-bit %s, "
          "multi-tier %s"
          % (eng["max_sh_u"], eng["max_sh_h"], eng["max_sh_z"],
             eng["max_align"], eng["worst_acc_bits_down"],
             eng["layers_over_31bit_acc"], eng["layers_multi_tier"]))
        out_vars.append(dict(
            policy=dict(opt, spec=spec, s_cap=args.s_cap,
                        r_quantile=args.r_quantile),
            verdict=dict(total_viol=V["total_viol"],
                         viol_by_class=V["viol_by_class"],
                         loss=V["loss"], loss_delta=V["loss"] - ref,
                         weights_only=wonly,
                         calibrates_formally=(V["total_viol"] == 0)),
            per_layer=V["per_layer"], shift_hists=hists, engine=eng,
            silu_wide_inventory=V["silu_wide_inventory"],
            silu_members=V["silu_members"]))
    rep = dict(
        experiment="m8b_blite_experiment (agent V: per-column pow2 "
                   "requant scales u/h/z + per-column w_down + widened "
                   "SiLU classes; exact-integer simulation)",
        checkpoint=str(args.ckpt), seed=args.seed,
        dims=dict(layers=arch.n_layers, d=arch.d, f=arch.f, t=args.t),
        truncated=bool(args.max_layers),
        loss_ref=ref, ref_source=src, positions=n_pos,
        baselines=dict(
            plain_chain_delta=base["verdict"]["loss_delta_nats"]["A"],
            plain_violations=base["verdict"]["range_violations"]["A"],
            weights_only_delta=base["verdict"]["loss_delta_nats"]
            ["weights_only"]),
        variants=out_vars,
        wall_s=time.time() - t0, peak_rss_gb=m8b.rss_gb())
    out = Path(args.bl_out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(rep, indent=1, default=jsonable))
    p()
    p("JSON -> %s" % out)
    p("wall %.0f s, peak RSS %.2f GB" % (rep["wall_s"],
                                         rep["peak_rss_gb"]))


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
                    choices=("stats", "plan", "run", "all", "blite"))
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
    # agent V (b-lite) flags — inert unless --phase blite
    ap.add_argument("--bl-variant", action="append", default=[],
                    help="b-lite variant spec (repeatable): "
                         "'name=P1,ucols,hcols,zcols,wdcols,"
                         "a16=all,g16=0;1;31,mx=2,mg=1,mu=1,mh=1,mz=1'")
    ap.add_argument("--bl-out",
                    default=str(ROOT / "results" /
                                "m8b_blite_experiment.json"))
    ap.add_argument("--bl-wonly", action="store_true",
                    help="also run the weights-only attribution walk "
                         "per variant")
    ap.add_argument("--equiv-check", action="store_true",
                    help="run m8b.run_variant alongside an all-per-"
                         "tensor blite variant and assert bit-equality")
    ap.add_argument("--validate-calibrate", action="store_true",
                    help="run a real m8b.calibrate walk and assert the "
                         "derived rows equal it")
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
    if args.phase == "blite":
        assert args.bl_variant, "--phase blite needs >= 1 --bl-variant"
        blite_phase(stats, store, arch, walker, cal, val, args, base)
        return
    run_phase(stats, store, arch, walker, cal, val, args, base)


if __name__ == "__main__":
    main()
