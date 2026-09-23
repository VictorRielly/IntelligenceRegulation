#!/usr/bin/env python3
"""ROUND 9i: rung-K8 against rung-K4, every figure, against the PREDICTION
written in the ledger (§R9i.4) before the gate read a rung-K8 bundle.

    python3 results/zk60_native_run_gate_k8/k8_vs_k4.py

Both records are BOTH-ARMS records of a DENSE bundle at three blocks
(`results/zk60_native_run_gate_mask/run-i-dense-k4.json` and this round's
`run-s-dense-k8.json`), so no figure moves for the block count or for an arm
one of them did not run.  `zk60_native_rg_witcmp.figures` pulls the same
flat figure set out of each.  Every figure is then exactly one of:

  * IDENTICAL at the two shapes -- the default; the prediction says every
    figure not listed below stays where rung-K4 has it;
  * PREDICTED TO MOVE, with the value §R9i.4 wrote down -- a miss is
    reported in `PREDICTIONS_THAT_MISSED`;
  * TRANSCRIPT-DRAWN -- the count of DISTINCT columns among 256 drawn, the
    pad margin and the pad-block rank derived from it; these move with the
    randomness, at any shape;
  * MOVED, NOT PREDICTED -- a figure §R9i.4 did not name.  Listed with the
    reading written AFTER the fact, so it is never mistaken for a
    prediction; and
  * UNEXPLAINED -- anything else, which is the round's result.

`round9c_table_form`: the output carries the keys `unexplained`,
`BROKEN_INVARIANTS`, `PREDICTIONS_THAT_MISSED` and `ok` of
`zk60_native_rg_m125table`, so a reader of round 9c's tables reads this one
the same way.  (That tool's classes are written for 125M against the rungs
-- block count, 125M wording -- and are not reused here.)
"""

from __future__ import annotations

import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
W = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(W, "scripts"))

from zk60_native_rg_witcmp import figures  # noqa: E402

K4 = os.path.join(W, "results", "zk60_native_run_gate_mask", "run-i-dense-k4.json")
K8 = os.path.join(HERE, "run-s-dense-k8.json")

# §R9i.4, the rows whose rung-K8 value differs from rung-K4's, as written
# at 20:24 before the gate read a rung-K8 bundle with its pins read.
PREDICTED = {
    "replay/challenges re-derived": 6926,
    "replay/final transcript counter": 7758,
    "hash layer/bytes hashed": 9385984,
    "group factor/lkv": 3,
    "group factor/group_point_entries_compared": 18,
    "group factor/coordinate_entries_compared": 144,
    "group factor/fixed_coordinates_compared_with_a_rederived_challenge": 60,
    "integrity/segment byte lengths": [4612392, 4634920, 4802824],
}
# per-commitment row counts (P8/P9): A 727 -> 733, H 720 -> 732
ROW_RE = re.compile(r"^rows/\d+:(A|H)$")
ROW_PRED = {"A": 733, "H": 732}
# P14: the group control family, 17 as the tools stood + GQ-7.1.2 (R9i-F1)
CONTROL_PRED = {"group factor/controls total": 18,
                "group factor/controls that fire": 18}
DRAWN_RE = re.compile(r"^(distinct opened columns/|pad margin/|"
                      r"pad block/(distinct columns|exact rank)$)")
# written AFTER the record was read, and labelled so
NOT_PREDICTED_READINGS = {
    # written 2026-09-22 20:47, AFTER the record was read
    "whole run/generators x classes":
        "308 x 4,505 -> 308 x 4,559.  The generator count, 308, is the half "
        "R9i.4 (P9) predicted and it did not move.  The CLASS count was not "
        "written down: `JointSystem` makes one coordinate class per row of "
        "every commitment, with the identified boundary rows unioned, so it "
        "is sum(rows) minus the identifications -- and the rows are "
        "predicted (A 727 -> 733, H 720 -> 732): +54 = 3 stages x (6 + 12), "
        "the Dom::Kv planes' extra rows, to the unit.  A consequence of "
        "predicted figures, derived after the fact and labelled so",
}


def main():
    with open(K4) as fh:
        k4 = figures(json.load(fh))
    with open(K8) as fh:
        k8 = figures(json.load(fh))
    keys = list(k8) + [k for k in k4 if k not in k8]
    rows = {"identical": [], "predicted": [], "transcript-drawn": [],
            "moved, not predicted": [], "unexplained": []}
    missed = []
    for k in keys:
        a, b = k4.get(k, "(absent)"), k8.get(k, "(absent)")
        row = {"figure": k, "rung-K4": a, "rung-K8": b}
        pred = PREDICTED.get(k, CONTROL_PRED.get(k))
        m = ROW_RE.match(k)
        if m:
            pred = ROW_PRED[m.group(1)]
        if a == b and pred is None:
            rows["identical"].append(row)
            continue
        if pred is not None:
            row["predicted"] = pred
            row["prediction_held"] = pred == b
            rows["predicted"].append(row)
            if pred != b:
                missed.append(row)
            continue
        if DRAWN_RE.match(k):
            rows["transcript-drawn"].append(row)
            continue
        if k in NOT_PREDICTED_READINGS:
            row["reading_written_after_the_record"] = NOT_PREDICTED_READINGS[k]
            rows["moved, not predicted"].append(row)
            continue
        rows["unexplained"].append(row)
    out = {
        "what": "rung-K8 (lkv 3) against rung-K4 (lkv 2), both-arms dense "
        "records, every figure against the prediction of ledger R9i.4",
        "records": [os.path.relpath(K4, W), os.path.relpath(K8, W)],
        "figures_compared": len(keys),
        "counts": {k: len(v) for k, v in rows.items()},
        "predictions_checked": len(rows["predicted"]),
        "PREDICTIONS_THAT_MISSED": missed,
        "BROKEN_INVARIANTS": [],
        "broken_invariants_note": "every figure NOT in the prediction's "
        "moving set is required IDENTICAL; one that moved is UNEXPLAINED, "
        "so the invariant class is the identical class here",
        "unexplained": rows["unexplained"],
        "per_class": rows,
        "this_is_not_a_privacy_result": True,
        "ok": not missed and not rows["unexplained"],
    }
    with open(os.path.join(HERE, "comparison_table_k8.json"), "w") as fh:
        json.dump(out, fh, indent=1, sort_keys=True)
        fh.write("\n")
    print(f"{out['figures_compared']} figures: {out['counts']}")
    for r in rows["predicted"]:
        print(f"  PREDICTED {r['figure']}: K4 {r['rung-K4']} -> K8 "
              f"{r['rung-K8']} (predicted {r['predicted']}, "
              f"{'held' if r['prediction_held'] else 'MISSED'})")
    for r in rows["moved, not predicted"]:
        print(f"  NOT PREDICTED {r['figure']}: {r['rung-K4']} -> {r['rung-K8']}")
    for r in rows["unexplained"]:
        print(f"  UNEXPLAINED {r['figure']}: {r['rung-K4']} -> {r['rung-K8']}")
    print(f"ok: {out['ok']}")
    return 0 if out["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
