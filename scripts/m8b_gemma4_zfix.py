#!/usr/bin/env python3
"""m8b_gemma4_zfix.py — U-PERF3 agent Z: the decisive Gemma-4-12B-QAT
z-site measurement for Victor's MVP-vehicle ruling.

THE QUESTION. The Gemma 4 C4 gate verdict (results/
m8b_gemma4_calibration.json, 2026-08-25) failed ONLY at the z site
(down-projection output, d-axis) at layers {2, 9, 21, 23, 24, 26}
(116,837 of 116,852 violations; delta +17.6029 nats vs ref 7.2367;
internals X/g/u/h essentially clean).  Does covering z with the C2
contract's per-channel mechanism rescue the QUALITY — yes or no, and
at what statement surface?

THE MECHANISM (agent V's `zcols` semantics, m8b_smooth_experiment.py
--phase blite, mirrored exactly — the cheapest C2 mechanism):
per-column eZ_j, a public d-vector of power-of-two exponents per
layer; the down-accumulator requant becomes a per-OUTPUT-column shift
sh_z_j = eZ_j - P_base (P_base = eH + eWd).  Post-accumulator: NO
alignment cost, accumulator bound unchanged.  Derivation (public,
calibration-window preprocessing):
    eZ_j = pow2ceil(absmax_j over the cal windows, fp walk) + mz
    eZ_j = max(eZ_j, pow2ceil(tensor z p999))     # V's robustness
                                                  # floor (sleepy cal
                                                  # columns)
    eZ_j = max(eZ_j, P_base)                      # shift >= 0 (fixups
                                                  # counted)

VARIANTS (same seed 1337, same FineWeb windows; deltas comparable to
the +17.6029 baseline; every non-z site stays at the BASELINE
per-tensor scales, reused verbatim from the baseline JSON):
  equiv  mechanism OFF everywhere — must reproduce the baseline
         verdict numbers EXACTLY (the equivalence gate).
  Z1     per-column eZ at ALL 48 layers (the mechanism's ceiling).
  Z2     per-column eZ ONLY at the hot layers {2,9,21,23,24,26}
         (= every layer with nonzero baseline z violations),
         per-tensor elsewhere — the minimal statement surface.
  Z3     int16 z class (Qz 32767, per-tensor eZ16) at the hot layers
         — the class-widening comparison point (run if Z1 leaves a
         material residual delta).

EXACTNESS DISCIPLINE: the simulation stays exact integers carried in
float64 (all values << 2^53; m125.floor_requant asserts remainder
bounds); z_out = yz * 2^eZ_j is exact in fp32 (|yz| <= 32767, PoT
scale).  The per-tensor path is g4.make_int8_ffn's inner loop copied
line-for-line; `equiv` asserts bit-identity against the recorded
baseline (loss, per-layer violation/accumulator/rel-err numbers).

Typical runs:
  # smoke (3 layers covering hot layer 2; walk-only, no head/loss):
  python3 scripts/m8b_gemma4_zfix.py --run smoke --max-layers 3
  # the full record pass (each variant ~10-20 min; incremental JSON):
  python3 scripts/m8b_gemma4_zfix.py --run equiv,Z1,Z2
  python3 scripts/m8b_gemma4_zfix.py --run Z3      # if Z1 says so
Output: results/m8b_gemma4_zfix_wsl.json (record) /
        results/m8b_gemma4_zfix_SMOKE.json (--max-layers runs);
per-column cal absmax cached at results/m8b_gemma4_zcol_stats.npz.
"""

import argparse
import json
import math
import sys
import time
from collections import Counter
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

import m125_int8_calibration as m125    # noqa: E402  (primitives, never edited)
import m8b_int8_calibration as m8b      # noqa: E402  (imported, never edited)
import m8b_gemma4_walker as g4          # noqa: E402  (the validated walker,
#                                                      imported UNCHANGED)
from m8b_int8_calibration import p, rss_gb           # noqa: E402
from m8b_gemma4_gelu_member import gelu_members      # noqa: E402

BASELINE_JSON = ROOT / "results" / "m8b_gemma4_calibration.json"
STATS_NPZ = ROOT / "results" / "m8b_gemma4_zcol_stats.npz"
OUT_RECORD = ROOT / "results" / "m8b_gemma4_zfix_wsl.json"
OUT_SMOKE = ROOT / "results" / "m8b_gemma4_zfix_SMOKE.json"


def pow2_exp_q(absmax, qmax):
    """m125.pow2_exp_for generalized to a Q other than 127 (identical
    formula; identical result at qmax=127)."""
    if absmax == 0:
        return -30
    return int(math.ceil(math.log2(absmax / qmax)))


# --------------------------------------------------------------------------
# per-column z calibration stats (fp reference walk over the SAME cal
# windows the baseline calibrated on; cached in an npz)
# --------------------------------------------------------------------------

def zcol_absmax(walker, cal, arch, force=False):
    if STATS_NPZ.exists() and not force:
        z = np.load(STATS_NPZ)
        if z["az"].shape[0] >= arch.n_layers and int(z["t"]) == cal.shape[1] - 1:
            p("zcol stats: reusing %s (layers %d, cal %dx%d)"
              % (STATS_NPZ, z["az"].shape[0], int(z["n_cal"]), int(z["t"])))
            return z["az"][:arch.n_layers]
    p("zcol stats: fp collect walk over the cal windows (%d x %d)..."
      % (cal.shape[0], cal.shape[1] - 1))
    az = np.zeros((arch.n_layers, arch.d), dtype=np.float64)

    def coll(li, d):
        az[li] = np.maximum(
            az[li],
            np.abs(d["z"].reshape(-1, arch.d).astype(np.float64)).max(axis=0))

    t0 = time.time()
    walker.walk(cal[:, :-1], collect=coll)
    p("zcol stats: done in %.0f s, RSS %.2f GB" % (time.time() - t0, rss_gb()))
    np.savez_compressed(STATS_NPZ, az=az, n_cal=cal.shape[0],
                        t=cal.shape[1] - 1, seed_note="windows from "
                        "m8b.token_batches(seed 1337) — the baseline's")
    p("zcol stats: -> %s" % STATS_NPZ)
    return az


# --------------------------------------------------------------------------
# the z-site configs (None = baseline per-tensor path, bit-identical)
# --------------------------------------------------------------------------

def make_zcfg(scales, az, arch, variant, mz, use_floor=True):
    """variant: 'equiv' | 'Z1' | 'Z2' | 'Z3'; hot = layers with nonzero
    baseline z violations. Returns (list per layer of None|dict, hot)."""
    hot = variant_hot(scales)
    cfgs = []
    for li in range(arch.n_layers):
        sc = scales[li]
        p_base = sc["eH"] + sc["eWd"]
        percol = (variant == "Z1") or (variant == "Z2" and li in hot)
        int16 = (variant == "Z3" and li in hot)
        if percol:
            e = np.array([pow2_exp_q(v, 127) for v in az[li]],
                         dtype=np.int64) + mz
            if use_floor:
                e = np.maximum(
                    e, pow2_exp_q(sc["stats"]["z"]["p999"], 127))
            n_fix = int((e < p_base).sum())
            e = np.maximum(e, p_base)
            cfgs.append(dict(kind="percol", qz=127, eZ=e,
                             sh=(e - p_base).astype(np.float64),
                             scale=(2.0 ** e.astype(np.float64)),
                             n_fix=n_fix))
        elif int16:
            e16 = pow2_exp_q(sc["stats"]["z"]["absmax"], 32767) + mz
            n_fix = int(e16 < p_base)
            e16 = max(e16, p_base)
            e = np.full(arch.d, e16, dtype=np.int64)
            cfgs.append(dict(kind="int16", qz=32767, eZ=e,
                             sh=(e - p_base).astype(np.float64),
                             scale=(2.0 ** e.astype(np.float64)),
                             n_fix=n_fix))
        else:
            cfgs.append(None)
    return cfgs, hot


def variant_hot(scales):
    base = json.loads(BASELINE_JSON.read_text())
    per_layer = base["int8_chain"]["variants"][0]["per_layer"]
    return sorted(li for li, pl in enumerate(per_layer)
                  if pl["viol"]["z_range"] > 0 and li < len(scales))


# --------------------------------------------------------------------------
# the chain: g4.make_int8_ffn's inner loop copied line-for-line, with
# the ONE surgical delta at the z requant when zcfg[li] is not None
# --------------------------------------------------------------------------

def make_zfix_ffn(scales, members, zcfg, acc_track, viol_track, err_track,
                  mode="floor"):
    def ffn(li, x, lw):
        sc = scales[li]
        B, T, C = x.shape
        tab = members[(sc["eGate"], sc["eA"])][0].astype(np.float64)
        Wq = {}
        for name, ekey in (("w_gate", "eWg"), ("w_up", "eWu"),
                           ("w_down", "eWd")):
            q, _ = m125.quantize(lw[name].astype(np.float64), sc[ekey])
            Wq[name] = q
        sh_g = sc["eGate"] - sc["eX"] - sc["eWg"]
        sh_u = sc["eUp"] - sc["eX"] - sc["eWu"]
        sh_h = sc["eH"] - sc["eA"] - sc["eUp"]
        sh_z = sc["eZ"] - sc["eH"] - sc["eWd"]
        c = zcfg[li]
        z_out = np.empty((B, T, C), dtype=np.float32)
        for b in range(B):
            xf = x[b].astype(np.float64)
            xq, xclip = m125.quantize(xf, sc["eX"])
            viol_track[li]["X_clip"] += xclip
            acc_g = xq @ Wq["w_gate"].T
            acc_u = xq @ Wq["w_up"].T
            acc_track[li]["gateup"] = max(acc_track[li]["gateup"],
                                          float(np.abs(acc_g).max()),
                                          float(np.abs(acc_u).max()))
            yg, vg = m125.narrow_int8(m125.floor_requant(acc_g, sh_g,
                                                         mode))
            yu, vu = m125.narrow_int8(m125.floor_requant(acc_u, sh_u,
                                                         mode))
            viol_track[li]["gate_range"] += vg
            viol_track[li]["up_range"] += vu
            aq = tab[(yg.astype(np.int64) + 128)]
            hq = aq * yu
            acc_track[li]["had"] = max(acc_track[li]["had"],
                                       float(np.abs(hq).max()))
            yh, vh = m125.narrow_int8(m125.floor_requant(hq, sh_h, mode))
            viol_track[li]["h_range"] += vh
            acc_d = yh @ Wq["w_down"].T
            acc_track[li]["down"] = max(acc_track[li]["down"],
                                        float(np.abs(acc_d).max()))
            if c is None:
                # baseline per-tensor path — g4.make_int8_ffn verbatim
                yz, vz = m125.narrow_int8(m125.floor_requant(acc_d, sh_z,
                                                             mode))
                viol_track[li]["z_range"] += vz
                z_out[b] = (yz * (2.0 ** sc["eZ"])).astype(np.float32)
            else:
                # THE MECHANISM: per-output-column shift, post-
                # accumulator (or the widened int16 class); exact.
                y = m125.floor_requant(acc_d, c["sh"][None, :], mode)
                vz = int(np.count_nonzero(np.abs(y) > c["qz"]))
                yz = np.clip(y, -c["qz"], c["qz"])
                viol_track[li]["z_range"] += vz
                z_out[b] = (yz * c["scale"][None, :]).astype(np.float32)
        # matched-input error: the fp GeGLU FFN on the SAME x (g4 verbatim)
        flat = x.reshape(B * T, C)
        gate = flat @ lw["w_gate"].T
        zf = ((g4.gelu_tanh(gate) * (flat @ lw["w_up"].T))
              @ lw["w_down"].T).astype(np.float64)
        zq = z_out.reshape(B * T, -1).astype(np.float64)
        num = float(np.sqrt(((zf - zq) ** 2).mean()))
        den = float(np.sqrt((zf ** 2).mean()))
        err_track[li].append(num / den if den else 0.0)
        return z_out

    return ffn


def run_zfix(walker, scales, members, zcfg, val, arch, label,
             with_loss=True):
    """g4.run_variant's accounting + the z-site engine/statement bill.
    with_loss=False walks the val windows without the streamed head
    (smoke: counters only)."""
    L = arch.n_layers
    acc_track = [dict(gateup=0.0, had=0.0, down=0.0) for _ in range(L)]
    viol_track = [dict(X_clip=0, gate_range=0, up_range=0, h_range=0,
                       z_range=0) for _ in range(L)]
    err_track = [[] for _ in range(L)]
    ffn = make_zfix_ffn(scales, members, zcfg, acc_track, viol_track,
                        err_track, mode="floor")
    t0 = time.time()
    if with_loss:
        loss = walker.loss(val, ffn_override=ffn)
    else:
        walker.walk(val[:, :-1], ffn_override=ffn)
        loss = None
    wall = time.time() - t0
    m_gu, b_gu = m125.acc_width(arch.d)
    m_dn, b_dn = m125.acc_width(arch.f)
    by_class = Counter()
    per_layer = []
    exp_hist = Counter()
    sh_hist = Counter()
    max_sh = -1
    stmt_bytes = 0
    p("%-6s %12s %12s %30s %10s  %s" % (
        "layer", "max|acc_f|", "z-mode", "violations (held-out)",
        "relFFNerr", "eZ[min..max] sh[min..max]"))
    for li in range(L):
        v = viol_track[li]
        by_class.update(v)
        assert acc_track[li]["gateup"] <= m_gu
        assert acc_track[li]["down"] <= m_dn
        c = zcfg[li]
        sc = scales[li]
        if c is None:
            zdesc = "tensor"
            sh_l = [sc["eZ"] - sc["eH"] - sc["eWd"]]
            e_l = [sc["eZ"]]
            zrec = dict(mode="tensor", eZ=sc["eZ"], sh_z=sh_l[0])
        else:
            zdesc = c["kind"]
            e_l = [int(c["eZ"].min()), int(c["eZ"].max())]
            sh_l = [int(c["sh"].min()), int(c["sh"].max())]
            exp_hist.update(Counter(c["eZ"].tolist()))
            sh_hist.update(Counter(c["sh"].astype(np.int64).tolist()))
            stmt_bytes += arch.d      # one i8 exponent per column
            zrec = dict(mode=c["kind"], qz=c["qz"],
                        eZ_min=e_l[0], eZ_max=e_l[-1],
                        sh_min=sh_l[0], sh_max=sh_l[-1],
                        n_shift_fixups=c["n_fix"],
                        exp_hist={str(k): int(n) for k, n in
                                  sorted(Counter(c["eZ"].tolist())
                                         .items())})
        max_sh = max(max_sh, sh_l[-1])
        p("%-6d %12.0f %12s %30s %10.4f  [%d..%d] [%d..%d]"
          % (li, acc_track[li]["down"], zdesc,
             "X:%d g:%d u:%d h:%d z:%d" % (
                 v["X_clip"], v["gate_range"], v["up_range"],
                 v["h_range"], v["z_range"]),
             float(np.mean(err_track[li])), e_l[0], e_l[-1],
             sh_l[0], sh_l[-1]))
        per_layer.append(dict(acc=acc_track[li], viol=viol_track[li],
                              rel_ffn_err=float(np.mean(err_track[li])),
                              z=zrec))
    total = sum(sum(v.values()) for v in viol_track)
    rec = dict(
        label=label, mode="floor", total_viol=total,
        viol_by_class=dict(by_class), loss=loss,
        acc_bounds=dict(gateup=[m_gu, b_gu], down=[m_dn, b_dn]),
        engine=dict(max_sh_z=int(max_sh),
                    statement_exp_bytes=int(stmt_bytes),
                    percol_layers=[li for li in range(L)
                                   if zcfg[li] is not None],
                    exp_hist_all={str(k): int(n) for k, n in
                                  sorted(exp_hist.items())},
                    sh_hist_all={str(k): int(n) for k, n in
                                 sorted(sh_hist.items())},
                    alignment_cost=0,
                    note="post-accumulator per-output-column shift: "
                         "no alignment, down-acc bound unchanged"),
        per_layer=per_layer, wall_s=wall, rss_gb=rss_gb())
    p("-> %s: %d violations %s; loss %s; max sh_z %d; statement "
      "exponent bytes %d; wall %.0f s, RSS %.2f GB"
      % (label, total, dict(by_class),
         "%.10f" % loss if loss is not None else "(walk-only)",
         max_sh, stmt_bytes, wall, rss_gb()))
    return rec


# --------------------------------------------------------------------------
# the equivalence gate (per-tensor path vs the recorded baseline)
# --------------------------------------------------------------------------

def equivalence_gate(rec, base, layers, with_loss=True):
    """Field-by-field EXACT comparison vs the baseline variant-A record
    (ints and float bits). Returns (ok, mismatches)."""
    bA = base["int8_chain"]["variants"][0]
    mism = []
    if with_loss:
        if rec["loss"] != bA["loss"]:
            mism.append("loss %r != baseline %r" % (rec["loss"],
                                                    bA["loss"]))
        if rec["total_viol"] != bA["total_viol"]:
            mism.append("total_viol %d != %d" % (rec["total_viol"],
                                                 bA["total_viol"]))
    for li in range(layers):
        mine, ref = rec["per_layer"][li], bA["per_layer"][li]
        if mine["viol"] != ref["viol"]:
            mism.append("l%d viol %r != %r" % (li, mine["viol"],
                                               ref["viol"]))
        for k in ("gateup", "had", "down"):
            if mine["acc"][k] != ref["acc"][k]:
                mism.append("l%d acc[%s] %r != %r"
                            % (li, k, mine["acc"][k], ref["acc"][k]))
        if mine["rel_ffn_err"] != ref["rel_ffn_err"]:
            mism.append("l%d rel_ffn_err %r != %r"
                        % (li, mine["rel_ffn_err"],
                           ref["rel_ffn_err"]))
    return (not mism), mism


# --------------------------------------------------------------------------

def incr_write(out_path, key, value):
    rep = json.loads(out_path.read_text()) if out_path.exists() else {}
    rep[key] = value
    out_path.write_text(json.dumps(rep, indent=1))
    p("JSON[%s] -> %s" % (key, out_path))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ckpt", default=g4.DEFAULT_CKPT)
    ap.add_argument("--text",
                    default=str(Path.home() / "models" / "fineweb-edu" /
                                "sample_text.txt"))
    ap.add_argument("--tokens", default=None)
    ap.add_argument("--t", type=int, default=512)
    ap.add_argument("--cal-seqs", type=int, default=8)
    ap.add_argument("--val-seqs", type=int, default=8)
    ap.add_argument("--seed", type=int, default=1337)
    ap.add_argument("--max-layers", type=int, default=None,
                    help="truncate the stack (SMOKE ONLY)")
    ap.add_argument("--mz", type=int, default=2,
                    help="margin bits on the per-column/int16 z exponent")
    ap.add_argument("--nofloor", action="store_true",
                    help="disable the tensor-p999 robustness floor")
    ap.add_argument("--restats", action="store_true",
                    help="force the zcol stats walk even if cached")
    ap.add_argument("--run", default="smoke",
                    help="comma list from {smoke,equiv,Z1,Z2,Z3}")
    args = ap.parse_args()

    runs = [r.strip() for r in args.run.split(",") if r.strip()]
    smoke_mode = "smoke" in runs or bool(args.max_layers)
    out_path = OUT_SMOKE if smoke_mode else OUT_RECORD

    base = json.loads(BASELINE_JSON.read_text())
    assert base["seed"] == args.seed and base["dims"]["t"] == args.t, \
        "seed/window mismatch vs the baseline JSON — deltas would not " \
        "be comparable"
    arch = g4.arch_gemma4(args.ckpt)
    if args.max_layers:
        arch.n_layers = min(arch.n_layers, args.max_layers)
    scales = base["calibration"][:arch.n_layers]
    assert len(scales) == arch.n_layers
    store = m8b.TensorStore(args.ckpt)
    walker = g4.Gemma4Walker(store, arch, args.t)
    members = gelu_members(scales)

    p("m8b_gemma4_zfix — %s, %d layers%s; scales REUSED from %s; "
      "runs: %s; mz %d floor %s"
      % (arch.tag, arch.n_layers,
         " ** TRUNCATED SMOKE — results are not the model's **"
         if args.max_layers else "",
         BASELINE_JSON.name, runs, args.mz, not args.nofloor))

    toks = m8b.load_token_stream(args, args.ckpt)
    cal, val = m8b.token_batches(toks, args.seed, args.cal_seqs,
                                 args.val_seqs, args.t)
    az = zcol_absmax(walker, cal, arch, force=args.restats)

    hot = variant_hot(scales)
    meta = dict(
        experiment="m8b_gemma4_zfix (agent Z: per-column eZ / int16 z "
                   "at the z site; everything else baseline per-tensor)",
        checkpoint=str(args.ckpt), seed=args.seed,
        dims=dict(layers=arch.n_layers, d=arch.d, f=arch.f, t=args.t),
        truncated=bool(args.max_layers),
        box="[MEASURED WSL-BOX NT]" if not args.max_layers
            else "[SMOKE TRUNCATED — not the model's numbers]",
        baseline=dict(json=str(BASELINE_JSON),
                      loss_ref=base["verdict"]["loss_ref"],
                      plain_delta=base["verdict"]["loss_delta_nats"]["A"],
                      plain_viol=base["verdict"]["range_violations"]["A"],
                      weights_only_delta=base["verdict"]
                      ["loss_delta_nats"]["weights_only"],
                      ref_source="baseline JSON loss_ref (same seed/"
                                 "windows/walker — deterministic)"),
        hot_layers=hot, mz=args.mz, floor=not args.nofloor,
        zcol_stats=str(STATS_NPZ))
    incr_write(out_path, "meta", meta)
    loss_ref = base["verdict"]["loss_ref"]

    if "smoke" in runs:
        # 1) equivalence on counters (loss not comparable when truncated)
        zcfg, _ = make_zcfg(scales, az, arch, "equiv", args.mz,
                            not args.nofloor)
        p("")
        p("== smoke equivalence: per-tensor path vs baseline layers "
          "0..%d (counters; walk-only) ==" % (arch.n_layers - 1))
        rec = run_zfix(walker, scales, members, zcfg, val, arch,
                       "smoke-equiv", with_loss=False)
        ok, mism = equivalence_gate(rec, base, arch.n_layers,
                                    with_loss=False)
        p("smoke equivalence gate: %s" % ("PASS — bit-identical counters"
                                          if ok else "FAIL"))
        for m in mism:
            p("  MISMATCH: %s" % m)
        incr_write(out_path, "smoke_equiv",
                   dict(passed=ok, mismatches=mism, record=rec))
        assert ok, "smoke equivalence gate FAILED"
        # 2) the mechanism at margins 0/1/2 (Z1-style, walk-only)
        for mz in (0, 1, 2):
            zcfg, _ = make_zcfg(scales, az, arch, "Z1", mz,
                                not args.nofloor)
            p("")
            p("== smoke mechanism: per-column eZ all layers, mz=%d ==" % mz)
            rec = run_zfix(walker, scales, members, zcfg, val, arch,
                           "smoke-percol-mz%d" % mz, with_loss=False)
            incr_write(out_path, "smoke_percol_mz%d" % mz, rec)
        p("")
        p("smoke done; peak RSS %.2f GB" % rss_gb())

    for name in runs:
        if name == "smoke":
            continue
        assert name in ("equiv", "Z1", "Z2", "Z3"), name
        zcfg, _ = make_zcfg(scales, az, arch, name, args.mz,
                            not args.nofloor)
        p("")
        p("== %s ==" % name)
        rec = run_zfix(walker, scales, members, zcfg, val, arch, name,
                       with_loss=True)
        rec["policy"] = dict(
            variant=name, mz=args.mz, floor=not args.nofloor,
            percol_layers=rec["engine"]["percol_layers"],
            qz=(32767 if name == "Z3" else 127),
            derivation="eZ_j = pow2ceil(cal fp absmax_j) + mz, floored "
                       "at the tensor z p999 exponent, clamped at "
                       "P_base = eH + eWd (agent V zcols semantics)"
                       if name != "Z3" else
                       "eZ16 = pow2ceil(cal fp tensor absmax / 32767) "
                       "+ mz, clamped at P_base")
        rec["delta_vs_ref"] = (rec["loss"] - loss_ref
                               if rec["loss"] is not None else None)
        if name == "equiv":
            ok, mism = equivalence_gate(rec, base, arch.n_layers,
                                        with_loss=True)
            rec["equivalence"] = dict(passed=ok, mismatches=mism)
            p("EQUIVALENCE GATE (full): %s"
              % ("PASS — loss and every per-layer counter bit-identical "
                 "to the baseline" if ok else "FAIL"))
            for m in mism:
                p("  MISMATCH: %s" % m)
            incr_write(out_path, "equiv", rec)
            assert ok, "full equivalence gate FAILED — stopping"
        else:
            p("-> %s delta vs ref %.4f: %+.4f nats (baseline plain "
              "chain %+.4f)"
              % (name, loss_ref, rec["delta_vs_ref"],
                 meta["baseline"]["plain_delta"]))
            incr_write(out_path, name, rec)
    p("")
    p("all requested runs done; peak RSS %.2f GB" % rss_gb())


if __name__ == "__main__":
    main()
