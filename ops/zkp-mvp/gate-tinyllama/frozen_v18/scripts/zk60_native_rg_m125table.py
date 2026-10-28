#!/usr/bin/env python3
"""ROUND 9's comparison table: every figure of the 125M record beside the
two development shapes', CLASSIFIED.

    python3 scripts/zk60_native_rg_m125table.py \
      --m125 results/.../m125-dense.json \
      --dev  results/zk60_native_run_gate_k4/run-i-dense-k4.json:rung-K4 \
      --dev  results/zk60_native_run_gate_s20/run-g-dense-s20.json:rung-G \
      --prediction results/.../prediction_m125.json \
      --out results/.../comparison_table.json

`zk60_native_rg_witcmp` already puts records side by side and says which
figures differ; it deliberately writes no reading.  This tool writes the
reading, and it writes it as a CLASSIFICATION that can fail:

* **INVARIANT** -- a figure the report's own laws say must be identical at
  every shape (the disclosed dimensions, the ranks of the blinding
  structure, `M`'s fifty rows and thirty-four functionals, the boundary's
  six of six, the three-role generator count, the channel table).  A
  difference here is a defect in a port or in a law, and it is the
  round's headline.
* **BLOCK COUNT** -- a figure that exists only because the development runs
  have three stages and the 125M runs have two.  Not a shape effect at all.
* **SCALES** -- a figure the shape must change, with the PREDICTED value
  beside the recorded one where the prediction named it.
* **UNEXPLAINED** -- everything else.  **An empty unexplained set is the
  only acceptable outcome, and a non-empty one is the round's result.**

NOTHING HERE IS A PRIVACY STATEMENT.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

from zk60_native_rg_joint import RULING_R3  # noqa: E402
from zk60_native_rg_witcmp import figures  # noqa: E402

# Figures the report's laws say are the SAME at every shape of this
# schedule.  Each entry is (pattern, the sentence that says why).
INVARIANT = [
    (r"^disclosed/\d+:A$", "A's disclosed dimension is a rank of the "
     "BLINDING structure -- mask rows, proximity rows, pads -- and that "
     "structure is a function of a_groups (36 at all three shapes), not of "
     "the geometry"),
    (r"^disclosed/\d+:H$", "H's 2 is the public LogUp identity, and the "
     "gate checks that it IS that identity"),
    (r"^disclosed/\d+:(Input|Output)$", "a singleton-group commitment"),
    (r"^disclosed/M@\d+$", "M commits no witness data"),
    (r"^rank_P1/\d+:A$", "2(a_groups + 1) = 74"),
    (r"^rank_P1/\d+:H$", "2(h_groups + 1) = 20"),
    (r"^k0/", "the disclosed dimension over Fp2 classes"),
    (r"^rows/M@\d+$", "layout.rs: M_ROWS = 2 * N_SLOTS + 4, a constant of "
     "the slot table"),
    (r"^opened columns/M@\d+$", "the mask domain's own column count"),
    (r"^pad count/", "Q = 256 pads per row at every shape so far"),
    (r"^boundary \d+/generators on the reserved block$", "2(G + 1) = 6"),
    (r"^boundary \d+/rank on the reserved block$", "ruling M-8's figure"),
    (r"^boundary \d+/full row rank$", "ruling M-8's figure"),
    (r"^boundary \d+/disclosed on the reserved block$", "ruling M-8's figure"),
    (r"^boundary \d+/rank over all rows$", "the figure M-1 says is "
     "worthless on its own; it is still the same"),
    (r"^boundary \d+/three-role (parts|sum|joint|generators)$",
     "74 + 6 + 74 generators, and every part 0"),
    (r"^boundary \d+/aliasing lost to the identification$", "0"),
    (r"^pair/stages 0 and 1 with boundary 0/(joint|sum)$",
     "two adjacent stages and the boundary between them disclose two "
     "copies of H's LogUp identity, 4 Fp, at every shape"),
    (r"^pad block/full rank$", "H-pad"),
    (r"^replay/(run binding reproduced|challenges NOT re-derived|hash rule)$",
     "the replay either reproduces everything or it does not"),
    (r"^integrity/findings$", "zero at every shape"),
    (r"^channels/", "the channel array is a property of the gate"),
    (r"^terminals/slots covered$", "23 slots at every shape of this "
     "schedule"),
    (r"^terminals/public tables taken from the capture$",
     "the same fifteen statement-dependent tables"),
    (r"^group factor/definition in force$", "the repaired definition"),
    (r"^preimage/half$", "round 1's arm is the message half"),
    (r"^preimage/free field elements per position$",
     "0 for a boundary, 1 for an endpoint"),
]

# Figures that exist only because the development runs are L = 3 and the
# 125M runs are L = 2.
BLOCK_COUNT = [
    (r"^(disclosed|rank_P1|rows|distinct opened columns|pad count|"
     r"pad margin|k0)/2:", "stage 2 exists only at L = 3"),
    (r"^(disclosed|rows|opened columns)/M@2$", "likewise"),
    (r"^boundary 1/", "the second internal boundary exists only at L = 3"),
    (r"^pair/stages 1 and 2 with boundary 1/", "likewise"),
    (r"^(disclosed|rank_P1|rows|distinct opened columns|pad count|"
     r"pad margin|k0)/1:Output$",
     "the output endpoint is opened in the LAST stage, which is stage 2 at "
     "L = 3 and stage 1 at L = 2"),
    (r"^(disclosed|rank_P1|rows|distinct opened columns|pad count|"
     r"pad margin|k0)/2:Output$", "likewise"),
    (r"^whole run/identified rows$",
     "2 * boundary data rows per equality slot, and L = 2 has four "
     "equality slots where L = 3 has six"),
    (r"^whole run/(sum of parts|joint)$",
     "one copy of H's LogUp identity per stage: 4 at L = 2, 6 at L = 3"),
    (r"^preimage/(attempted|commitments exhibited)$",
     "L = 3 has four singleton-group commitments, L = 2 has three"),
    (r"^terminals/(checks equal|checks expected|"
     r"matching the stored terminal_polynomial)$",
     "23 slots per stage: 46 at L = 2, 69 at L = 3"),
    (r"^group factor/(group points|coordinate lists|"
     r"group point entries|coordinate entries|fixed coordinates)",
     "one group point per bilinear slot per stage"),
    (r"^hash layer/openings$", "3L + 1 PCS openings plus L masking ones"),
    (r"^replay/segment position tags ok$", "two per stage"),
]

# Figures the shape must change.  The second element is the prediction key
# when this round predicted the figure before reading the record.
SCALES = [
    (r"^rows/\d+:", None, "the commitment's own row count"),
    (r"^distinct opened columns/", None,
     "the number of DISTINCT indices among 256 drawn with replacement out "
     "of the encoded width, which is 4,096 at the rungs and 65,536 here"),
    (r"^pad margin/", None, "256 minus the distinct count"),
    (r"^pad block/(distinct columns|exact rank)$", None, "likewise"),
    (r"^replay/positions_checked$", "replay.positions_checked", ""),
    (r"^replay/transcript positions$", "replay.positions_checked",
     "1 + L(1 + 5 slots + 2) + 2 per opening"),
    (r"^replay/challenges re-derived$", "replay.challenges_checked",
     "the proximity rho of every row of every opening dominates"),
    (r"^replay/final transcript counter$", None, "every squeeze, compared "
     "or not"),
    (r"^hash layer/columns checked$", "hash_layer.columns", ""),
    (r"^hash layer/columns authenticated$", "hash_layer.columns", ""),
    (r"^hash layer/bytes hashed$", "hash_layer.column_bytes",
     "256 columns of `rows` field elements per opening"),
    (r"^whole run/generators x classes$", None,
     "206 generators at L = 2 against 308 at L = 3, and the classes grow "
     "with the message width"),
    (r"^integrity/segment byte lengths$", None, "the receipt's own size"),
    (r"^rank_P1/\d+:(Input|Output)$", None,
     "2(G + 1) for the opening's own group count: 4 for an endpoint, 6 for "
     "a boundary"),
    (r"^group factor/lkv$", None,
     "clog2(kv_heads): 2 at 125M and at rung-K4, 1 at rung-G -- the axis "
     "round 5 was written for"),
    (r"^boundary \d+/reserved rows$", None,
     "the boundary's own row count, data + 2*sites + 2: 38 at 125M "
     "(32 data rows) against 10 at the rungs (4)"),
    (r"^group factor/", None, "a count that follows the slot and stage "
     "count"),
    (r"^terminals/(public tables rebuilt|public table structure checks|"
     r"derived group points used|controls that fire|controls total)$", None,
     "per stage, or per shape's own table set"),
    (r"^public tables/", None, "per stage"),
    (r"^hash layer/controls that fire$", None, "the control set is the same; "
     "a pass that supplies no cross-profile bundle fires fewer"),
    (r"^run controls/", None, "the control set of a pass that ran them"),
]


def _classify(fig):
    # BLOCK COUNT first: a figure that exists only at L = 3 is a block-count
    # matter, not an invariant that moved, and testing invariance first would
    # let the invariant class swallow it.
    for pat, why in BLOCK_COUNT:
        if re.match(pat, fig):
            return "block count", why, None
    for pat, why in INVARIANT:
        if re.match(pat, fig):
            return "invariant", why, None
    for pat, key, why in SCALES:
        if re.match(pat, fig):
            return "scales", why, key
    return "unexplained", None, None


def _pget(pred, dotted):
    o = pred
    try:
        for k in dotted.split("."):
            o = o[k]
    except (KeyError, TypeError):
        return None
    return o


def build(m125_rec, devs, prediction) -> dict:
    m = figures(m125_rec)
    tabs = [(lab, figures(rec)) for lab, rec in devs]
    keys = list(m)
    for _lab, t in tabs:
        for k in t:
            if k not in keys:
                keys.append(k)

    rows = {"invariant": [], "block count": [], "scales": [],
            "unexplained": []}
    broken_invariants = []
    prediction_misses = []
    for k in keys:
        here = m.get(k, "(absent)")
        there = [t.get(k, "(absent)") for _lab, t in tabs]
        kind, why, pkey = _classify(k)
        same = all(v == here for v in there)
        row = {"figure": k, "m125": here,
               **{lab: t.get(k, "(absent)") for lab, t in tabs},
               "identical": same}
        if kind == "invariant":
            row["why_it_must_not_move"] = why
            present = [v for v in there if v != "(absent)"]
            if present and any(v != here for v in present) \
                    and here != "(absent)":
                broken_invariants.append(row)
        if kind == "scales":
            row["why_it_moves"] = why
            if pkey:
                p = _pget(prediction, pkey)
                row["predicted"] = p
                row["prediction_held"] = (p == here)
                if p is not None and p != here:
                    prediction_misses.append(row)
        if kind == "block count":
            row["why_it_moves"] = why
        rows[kind].append(row)

    return {
        "what": "every figure of the 125M record beside the two development "
        "shapes', classified as INVARIANT (a law of the report says it must "
        "not move), BLOCK COUNT (L = 2 against L = 3), SCALES (with the "
        "prediction beside it where this round predicted it) or UNEXPLAINED",
        "the_only_acceptable_outcome": "an empty unexplained set and an "
        "empty broken-invariant set.  A non-empty one is the round's result "
        "and belongs in the report's headline, not in a footnote",
        "shapes": ["125M (2 blocks)"] + [lab for lab, _r in devs],
        "figures_compared": len(keys),
        "counts": {k: len(v) for k, v in rows.items()},
        "invariants_that_are_identical_at_all_three_shapes": sum(
            1 for r in rows["invariant"] if r["identical"]),
        "invariants_present_only_at_some_shapes": sum(
            1 for r in rows["invariant"] if not r["identical"]
            and "(absent)" in [r["m125"]] + [r[lab] for lab, _t in devs]),
        "BROKEN_INVARIANTS": broken_invariants,
        "predictions_checked": sum(
            1 for r in rows["scales"] if "prediction_held" in r),
        "PREDICTIONS_THAT_MISSED": prediction_misses,
        "unexplained": rows["unexplained"],
        "per_class": rows,
        "ruling_R3": RULING_R3,
        "this_is_not_a_privacy_result": True,
        "ok": not broken_invariants and not prediction_misses
        and not rows["unexplained"],
    }


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--m125", required=True)
    ap.add_argument("--dev", action="append", required=True,
                    metavar="RECORD.json:LABEL")
    ap.add_argument("--prediction", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args(argv)

    with open(args.m125) as fh:
        m = json.load(fh)
    devs = []
    for spec in args.dev:
        p, lab = spec.rsplit(":", 1)
        with open(p) as fh:
            devs.append((lab, json.load(fh)))
    with open(args.prediction) as fh:
        pred = json.load(fh)["prediction"]

    out = build(m, devs, pred)
    with open(args.out, "w") as fh:
        json.dump(out, fh, indent=1, sort_keys=True)
        fh.write("\n")
    print(f"{out['figures_compared']} figures: " + ", ".join(
        f"{k} {v}" for k, v in out["counts"].items()))
    print(f"invariants identical at all three shapes: "
          f"{out['invariants_that_are_identical_at_all_three_shapes']}")
    print(f"BROKEN INVARIANTS: {len(out['BROKEN_INVARIANTS'])}")
    for r in out["BROKEN_INVARIANTS"]:
        print("   ", r["figure"], r["m125"], "against",
              [v for k, v in r.items() if k.startswith("rung")])
    print(f"predictions checked: {out['predictions_checked']}, "
          f"missed: {len(out['PREDICTIONS_THAT_MISSED'])}")
    for r in out["PREDICTIONS_THAT_MISSED"]:
        print("   ", r["figure"], "predicted", r["predicted"], "got",
              r["m125"])
    print(f"UNEXPLAINED: {len(out['unexplained'])}")
    for r in out["unexplained"]:
        print("   ", r["figure"], "=", r["m125"])
    print(f"-> {args.out}")
    return 0 if out["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
