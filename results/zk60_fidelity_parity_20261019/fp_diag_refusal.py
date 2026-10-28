#!/usr/bin/env python3
"""Fidelity lane diagnostic (2026-10-21): the UNCLAMPED values behind refusals of an fp_eval run.

Re-runs the integer stack of one fp_eval configuration on the named sequences only, up to the last
refused layer, and at each refused (layer, site) records the value that left its range, the range,
and the zero-cost change that would admit it:
  score  : max |s| over heads at the refused position vs 2^(7+ks) - 1 -> extra SH_S bits needed at that layer
  FFN gate (group SiLU what-if): the channel(s) whose real gate value leaves 127 2^e_j, its member e_j,
           the coarsest registry member (-1, range 63.5), the calibration channel / tensor maxima.
Inputs to a sequence's first refused layer are bit-identical to the fp_eval run (no clamp happened
before it in that sequence). Fidelity data, not a proof, not a privacy claim.

usage: ZK60_MODEL=llama3-8b python3 fp_diag_refusal.py --run e8_LOWh8v6_lam0
"""
import argparse
import json
import os
import pickle
import time
from pathlib import Path

import numpy as np

import fp_data
import fp_lib as fl
from fp_lib import GEO, b3, tc


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--run", required=True, help="fp_eval tag (its summary.json names export, corpora, mods, gate_pc, mult_bits)")
    ap.add_argument("--gate-pc", default="", help="override the run's group-SiLU spec (e.g. -5:mc8:tm4:ng4) - a zero-cost bound change")
    ap.add_argument("--sh-s-plus", default="", help="'layer:bits,...': SH_S and the exp-table e_s of that layer + bits (score range 2^bits wider)")
    ap.add_argument("--to-end", action="store_true", help="run the refused sequences through ALL layers and record every violation (fix check)")
    ap.add_argument("--out", default="refusal_diag.json")
    a = ap.parse_args()
    shs_plus = {int(k): int(v) for k, v in (t.split(":") for t in a.sh_s_plus.split(",") if t)}
    runs = fl.HERE / "runs" / fl.MODEL
    s = json.loads((runs / a.run / "summary.json").read_text())
    where = s["violations_where"]
    assert where, "no refusals in that run"
    seqs = sorted({w["seq"] for w in where})
    first = {}
    for w in where:                       # first refused layer per sequence
        first[w["seq"]] = min(first.get(w["seq"], 99), w["layer"])
    targets = {(w["layer"], w["site"], w["seq"], w["pos"]) for w in where if w["layer"] == first[w["seq"]]}
    Lmax = max(first.values())
    if a.to_end:
        Lmax = None
    ex = fl.Export(Path(s["export"]) if Path(s["export"]).is_absolute() else fl.HERE / "exports" / s["export"], verify=False)
    T = ex.T
    ids_all, meta, mask, info = fp_data.build(fl.MODEL, T, s["corpora"]["spec"])
    ids = ids_all[seqs]
    mods = frozenset(m for m in (s.get("mods") or "").split(",") if m)
    mb = s.get("mult_bits") or ""
    mb = mb.get("spec", "") if isinstance(mb, dict) else mb
    mbits = {k: int(v) for k, v in (t.split(":") for t in mb.split(",") if t)}
    gspec = a.gate_pc or (s.get("gate_pc") or {}).get("spec", "")
    gt_ = gspec.split(":") if gspec else []
    gmin = int(gt_[0]) if gt_ else None
    gmc = next((float(t[2:]) for t in gt_[1:] if t.startswith("mc")), 2.0)
    gm2 = next((float(t[2:]) for t in gt_[1:] if t.startswith("tm")), 1.25)
    gng = next((int(t[2:]) for t in gt_[1:] if t.startswith("ng")), None)
    stats = pickle.load(open((fl.C8 / "runs" / "b5_stats_T128_n30_r1_L32.pkl") if fl.IS8B else
                             (fl.CAL / "runs" / "b3_stats4_T128_c6_r1_b4fw54.pkl"), "rb")) if gspec else None
    fl.log(f"diag {a.run}: seqs {seqs} first refused layers {first} mods {sorted(mods)} mult {mbits} gate {gspec}")
    tab = ex.embedding_table()
    x = np.asarray(tab[ids.reshape(-1)], dtype=np.float64).reshape(*ids.shape, GEO.d)
    ck = fl.checkpoint()
    exact = frozenset(fl.SITES)
    out, viol = [], []
    for l in range(ex.L if Lmax is None else Lmax + 1):
        tl = time.time()
        Lw = ex.layer(l)
        if l in shs_plus:
            c2_ = dict(Lw["c"])
            c2_["sh_s"] = int(c2_["sh_s"]) + shs_plus[l]
            c2_["e_s"] = int(c2_["e_s"]) + shs_plus[l]
            w2_ = dict(Lw["w"])
            w2_["exp"] = b3.exp_generate(c2_["e_s"], GEO.dh, int(c2_["f_e"]), len(Lw["w"]["exp"]))
            Lw = {"w": w2_, "c": c2_, "manifest": Lw["manifest"]}
        Wreal = None
        if mbits:
            Wreal, _ = fl.real_weights(b3.rotate_layer(tc.layer_f32(ck, l), ex.R), Lw)
            neww, mult, _ = fl.apply_multipliers(Lw, Wreal, mbits)
            Lw = {"w": neww, "c": Lw["c"], "manifest": Lw["manifest"]}
        M = fl.LayerModel(Lw, T, Wreal, mods)
        if mbits:
            M.mult = mult
        g = None
        if stats is not None:
            g = fl.gate_groups(stats[l], gmin, mc=gmc, m2=gm2, ngroups=gng)
            M.gate_pc = g[:4]
        here = [t for t in targets if t[0] == l]
        if here:
            tr = {}
            fl.rx_block(x, M, exact, None, trace=tr)     # rec None: no clamp, raw values
            c = M.c
            for (_, site, sq, pos) in here:
                i = seqs.index(sq)
                rec = {"layer": l, "site": site, "seq": sq, "pos": pos, "token": int(ids_all[sq, pos]), "constants": {k: c[k] for k in ("sh_qkv", "sh_s", "exp_e_s") if k in c}}
                if site == "score":
                    ks = fl._modk(M, "s")
                    LS = (1 << (7 + ks)) - 1
                    sc = tr["s"][i]                                  # (KV, G, T, T)
                    full = np.abs(sc[:, :, pos, :])                   # the native relation range-checks ALL (t, j), masked too
                    rec["max_abs_score_causal"] = float(np.abs(sc[:, :, pos, :pos + 1]).max())
                    rec["max_abs_score_layer_seq"] = float(np.abs(sc).max())
                    row = full
                    mx = float(row.max())
                    kv, gq, kpos = np.unravel_index(int(np.argmax(row)), row.shape)
                    rec.update({"max_abs_score": mx, "limit": LS, "factor": mx / LS, "extra_sh_s_bits": int(np.ceil(np.log2(mx / LS))) if mx > LS else 0,
                                "kv_head": int(kv), "q_in_group": int(gq), "key_pos": int(kpos), "key_token": int(ids_all[sq, kpos]),
                                "calib_raw_kv_max": float(np.asarray(stats[l]["raw_kv"]).max()) if stats is not None else None})
                elif site == "FFN gate" and g is not None:
                    ej, eoj = g[0], g[1]
                    kg = fl._modk(M, "g")
                    e_in = c["silu"][0]
                    xg = tr["g8"][i, pos] * (2.0 ** e_in)            # real gate value per channel
                    hi = ((1 << (7 + kg)) - 1) * 2.0 ** (ej - kg)
                    lo = -(1 << (7 + kg)) * 2.0 ** (ej - kg)
                    bad = np.nonzero((xg > hi) | (xg < lo))[0]
                    st = stats[l]
                    rec.update({"channels": [{"ch": int(j), "gate": float(xg[j]), "e_j": int(ej[j]), "range": [float(lo[j]), float(hi[j])],
                                              "coarsest_registry_range": 127.94 * 0.5, "needs_e": int(np.ceil(np.log2(abs(xg[j]) / 127.94))),
                                              "calib_channel_max": float(st["gate_max"][j]), "calib_tensor_max": float(max(st["gate_pos"], st["gate_neg"]))}
                                             for j in bad[:8]],
                                "n_bad_channels": int(len(bad))})
                out.append(rec)
                fl.log(f"  {json.dumps(rec)}")
        r = fl.RecPos(len(ids))
        x = fl.rx_block(x, M, exact, r).astype(np.float32).astype(np.float64)
        for (site, si, pi), cnt in r.where.items():
            viol.append({"layer": l, "site": site, "seq": seqs[si], "pos": pi, "count": cnt})
        fl.log(f"L{l:02d} violations {sum(1 for v in viol if v['layer'] == l)} ({time.time() - tl:.0f}s)")
        del M, Wreal
    dst = runs / a.run / a.out
    dst.write_text(json.dumps({"run": a.run, "seqs": seqs, "first_refused_layer": {str(k): v for k, v in first.items()},
                               "overrides": {"gate_pc": gspec, "sh_s_plus": shs_plus, "to_end": a.to_end},
                               "records": out, "violations": viol, "scope": "fidelity data, not a proof, not a privacy claim"}, indent=1))
    fl.log(f"wrote {dst}")


if __name__ == "__main__":
    main()
