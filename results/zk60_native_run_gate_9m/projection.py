#!/usr/bin/env python3
"""ROUND 9m: the PROJECTION -- time and peak resident memory of every pass of
the staged 125M driver at L = 12, from what the L = 2 (and L = 1) 125M passes
MEASURED and from how each part of the gate scales with L.  Written and
committed BEFORE any pass is run at L = 12, and read against the stop rule:

  * no pass whose projected peak exceeds ~11 GiB is run;
  * the "everything" (full preimage + every control) pass is run only if it
    is projected <= 11 GiB AND <= 4 h.

    python3 results/zk60_native_run_gate_9m/projection.py

Every input is a MEASURED figure with its source; every scaling law is
stated.  One measurement at L = 12 precedes this file and is disclosed: the
failing-first `load` probe (`probe_before_repin/`, 4.4 s, peak RSS 1,555 MB),
which refused at the pins and computed no figure the prediction names.
"""

from __future__ import annotations

import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
L = 12
MB = 1.0
GIB = 1024.0

# ---------------------------------------------------------------- inputs
# (seconds, peak RSS MB) per stage of the staged driver, MEASURED.
L2 = {  # round 9c's re-take of m125-dense (`m125-dense.json` timings) and
        # dense-final / zero-full / dense-everything2 / dense-controls3 logs
    "load": (1.0, 603), "replay": (1.3, 603), "hash": (0.8, 603),
    "terminals": (101.6, 1460), "commitments": (62.8, 1460),
    "boundary": (5.5, 1460), "preimage": (1.0, 1460),
    "terminals_with_controls": (1664.5, 1531),        # dense-controls3.log
    "mask_with_controls": (42.8, None),                # dense-controls3.log
    "mask_without_controls": (15.4, None),             # zero-full.log
    "runcontrols": (256.3, 2105),                       # dense-controls3.log
    "fullpreimage_arm_only": (1293.8, 4020),           # zero-full.log (no controls)
    "fullpreimage_with_P_controls": (5712.1, 5484),    # dense-full.log
    "everything_total": (7797.8, 5484),                 # dense-everything2.log
}
L1_BLOCK = {  # round 9j pass A / 9l on the standalone 125M block (one stage)
    "load": (0.6, 323), "terminals": (44.4, 1402), "commitments": (49.5, 370),
    "boundary": (0.8, 407),
}
L12_MEASURED = {"load": (4.4, 1555)}  # the failing-first probe

# the fixed parts, MEASURED
PAD_RANK_S = 47.2          # stage 3's H-pad cross-check on B0 (m125-dense.json)
A_ARM_S, H_ARM_S = 314.0, 258.0   # round 9 dense-full: A@0 315.3 / A@1 317.1, H 249.6 / 267.0
B_ARM_S, E_ARM_S = 50.0, 44.0     # the three small ones 43.7 / 50.1 / 49.9
P_CONTROLS_S = 4420.0      # 5,712.1 - 1,292.7: P-1..P-6 on A@0 / H@0, fixed in L
M_CONTROLS_S = 42.8 - 15.4 # M1..M6 on stage 0, fixed in L
TERMINAL_CHECK_PER_STAGE_S = 101.6 / 2
TERMINAL_CONTROL_EXTRA_S = 1664.5 - 101.6   # ~18 whole-run re-checks at L = 2

# ---------------------------------------------------------- the geometry
GENS = {"A": 74, "H": 20, "E": 4, "B": 6, "M": 2}
ROWS = {"A": 5681, "H": 7120, "E": 37, "B": 38, "M": 50}


def whole_run(l):
    gens = l * (GENS["A"] + GENS["H"] + GENS["M"]) + 2 * GENS["E"] + (l - 1) * GENS["B"]
    rows = l * (ROWS["A"] + ROWS["H"] + ROWS["M"]) + 2 * ROWS["E"] + (l - 1) * ROWS["B"]
    ident = 64 + 64 * (l - 1)
    return gens, rows - ident, rows, ident


def main():
    g2, c2, _, _ = whole_run(2)
    g12, c12, r12, i12 = whole_run(L)
    assert (g2, c2) == (206, 25686), (g2, c2)       # the L = 2 record's matrix
    cells2, cells12 = g2 * c2, g12 * c12
    one_copy_gb = cells12 * 8 / 1e9                  # a list of pointers
    # RunJointSystem.disclosed: gens (1 copy) + rank()'s working copy (1) +
    # exact_u_term's D-union-N' sub-matrix (1) + its rank copy (1), of which
    # at most three are alive at once; plus the Fp objects of the nonzero
    # entries (a block's generators are supported on its own rows)
    nnz12 = L * (GENS["A"] * ROWS["A"] + GENS["H"] * ROWS["H"]) \
        + 2 * GENS["E"] * ROWS["E"] + (L - 1) * GENS["B"] * ROWS["B"]
    stage4_increment_gb = 3 * one_copy_gb + 2 * nnz12 * 40 / 1e9
    base_before_stage4_gb = 1.3                      # load's resident part + views
    stage4_peak_gb = base_before_stage4_gb + stage4_increment_gb

    scale = L / 2
    t = {}
    t["load"] = L12_MEASURED["load"][0]
    t["replay"] = L2["replay"][0] * scale
    t["hash"] = L2["hash"][0] * scale
    t["terminals"] = TERMINAL_CHECK_PER_STAGE_S * L
    t["commitments"] = PAD_RANK_S + (L2["commitments"][0] - PAD_RANK_S) * scale
    # the whole-run ranks are O(gens * classes) = O(L^2) per elimination;
    # the per-indicator u-term solves are O(L^3); 11 adjacent-pair systems
    # of the L = 2 size; 11 three-role systems
    t["boundary"] = (2.0 * (cells12 / cells2)          # generators + two full ranks
                     + 0.5 * (L / 2) ** 3               # the u-term solves
                     + (L - 1) * 3.0)                   # the adjacent pairs
    t["preimage"] = L2["preimage"][0] * (2 + (L - 1)) / 3
    t["arm"] = L * (A_ARM_S + H_ARM_S) + (L - 1) * B_ARM_S + 2 * E_ARM_S
    t["mask_controls"] = L2["mask_without_controls"][0] / 2 * L + M_CONTROLS_S
    t["runcontrols_without_M9_3"] = 300.0
    t["terminal_control_families"] = TERMINAL_CONTROL_EXTRA_S * scale
    t["m9_3"] = 4 * TERMINAL_CHECK_PER_STAGE_S * L

    base = t["load"] + t["replay"] + t["hash"] + t["commitments"] + t["boundary"] + t["preimage"]
    passes = {
        "A (records of record): load,replay,hash,terminals,commitments,boundary,preimage,channels": {
            "seconds": base + t["terminals"],
            "peak_gb": max(L12_MEASURED["load"][1] / 1000, 2.2, stage4_peak_gb),
            "why_the_peak": "stage 4's whole-run joint system (dense Python lists)",
        },
        "M (mask and CFS per stage, M1-M6): load,replay,mask --controls": {
            "seconds": t["load"] + t["replay"] + t["mask_controls"],
            "peak_gb": L12_MEASURED["load"][1] / 1000 + 0.2,
            "why_the_peak": "the load (arrays.bin hashed once)",
        },
        "F (every arm + the per-stage / per-boundary controls, no terminals): load,replay,hash,commitments,boundary,preimage,fullpreimage,mask,joint,runcontrols,channels --controls": {
            "seconds": base + t["arm"] + P_CONTROLS_S + t["mask_controls"]
            + t["runcontrols_without_M9_3"],
            "peak_gb": max(stage4_peak_gb, base_before_stage4_gb + 5.5),
            "why_the_peak": "stage 4, then the arm's per-commitment solve with round 7's controls (5.5 GB above the L = 2 base, measured)",
        },
        "T (the whole-run terminal control families CT, GQ and M9-3)": {
            "seconds": t["load"] + t["replay"] + t["terminals"] + t["terminal_control_families"]
            + t["commitments"] + t["boundary"] + t["m9_3"],
            "peak_gb": stage4_peak_gb,
            "why_the_peak": "stage 4 (runcontrols needs the views and the shared planes)",
        },
        "EVERYTHING (every stage, every arm, every control)": {
            "seconds": base + t["terminals"] + t["terminal_control_families"] + t["arm"]
            + P_CONTROLS_S + t["mask_controls"] + t["runcontrols_without_M9_3"] + t["m9_3"],
            "peak_gb": max(stage4_peak_gb, base_before_stage4_gb + 5.5),
            "why_the_peak": "as F",
        },
    }
    for k, p in passes.items():
        p["hours"] = round(p["seconds"] / 3600, 2)
        p["seconds"] = round(p["seconds"])
        p["peak_gb"] = round(p["peak_gb"], 1)
        p["fits_11_gib"] = p["peak_gb"] <= 11 * 1.073741824   # GB vs GiB
        p["within_4_h"] = p["seconds"] <= 4 * 3600
    out = {
        "what": __doc__.split("\n\n")[0],
        "inputs_measured_at_L2": L2,
        "inputs_measured_at_L1_block": L1_BLOCK,
        "measured_at_L12_before_this_file": L12_MEASURED,
        "whole_run_system": {
            "L2": f"{g2} x {c2}", "L12": f"{g12} x {c12}",
            "rows_total_L12": r12, "identified_rows_L12": i12,
            "cells_ratio": round(cells12 / cells2, 1),
            "one_dense_copy_gb": round(one_copy_gb, 2),
            "nonzero_generator_entries_L12": nnz12,
            "stage4_increment_gb": round(stage4_increment_gb, 1),
            "stage4_peak_gb": round(stage4_peak_gb, 1),
        },
        "stage_seconds_L12": {k: round(v, 1) for k, v in t.items()},
        "passes": passes,
    }
    with open(os.path.join(HERE, "projection_l12.json"), "w") as fh:
        json.dump(out, fh, indent=1, sort_keys=True)
        fh.write("\n")
    print(json.dumps(out["whole_run_system"], indent=1))
    print(json.dumps(out["stage_seconds_L12"], indent=1))
    for k, p in passes.items():
        print(f"{p['hours']:5.2f} h  {p['peak_gb']:4.1f} GB  fits={p['fits_11_gib']} "
              f"4h={p['within_4_h']}  {k}")


if __name__ == "__main__":
    main()
