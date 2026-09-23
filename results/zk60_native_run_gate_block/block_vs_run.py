#!/usr/bin/env python3
"""ROUND 9j, J5: a STANDALONE block against the RUN it would be a stage of.

    python3 results/zk60_native_run_gate_block/block_vs_run.py

For each shape, the block record's figures beside the run record's PER-STAGE
figures, each row labelled with the rule that relates them (R9j.4):

  SAME        a per-commitment or per-stage figure that must be identical
              (A's and H's rows, claims, groups, disclosed dimension,
              rank_P1; M's rows and its CFS entries per stage; slot checks
              per stage; the endpoint's geometry);
  ARITHMETIC  a whole-proof figure the block derives from one run stage
              (challenges = stage 0's + E-Output's lambda and rows;
              positions; openings; whole-system generators and classes);
  NONE        a run figure with no block counterpart (boundaries, segment
              tags, the three-role figure).

Nothing here is a privacy statement.
"""

from __future__ import annotations

import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
W = os.path.dirname(os.path.dirname(HERE))

PAIRS = (
    ("rung-G", "block-rung-g-dense.json",
     os.path.join(W, "results", "zk60_native_run_gate_mask", "run-g-dense-s20.json")),
    ("125M", "block-m125-dense-everything.json",
     os.path.join(W, "results", "zk60_native_run_gate_m125",
                  "m125-dense-everything.json")),
)


def load(p):
    if not os.path.exists(p):
        return None
    with open(p) as fh:
        return json.load(fh)


def per_commitment(rec):
    return {r["role"]: r for r in rec["stage3_per_commitment"]["per_commitment"]}


def compare(shape, blk, run):
    rows = []

    def add(fig, b, r, rule):
        rows.append({"figure": fig, "block": b, "run": r, "rule": rule,
                     "holds": (b == r) if rule == "SAME" else None})

    bpc, rpc = per_commitment(blk), per_commitment(run)
    for role, run_key in (("A@0", "A@0"), ("H@0", "H@0"), ("E-Input", "E-Input"),
                          ("E-Output", "E-Output")):
        for f in ("rows", "claims", "groups", "disclosed_dimension", "rank_P1",
                  "k0", "non_data_rows"):
            add(f"{role}/{f}", bpc[role].get(f), rpc[run_key].get(f), "SAME")
    add("M rows", blk["stage3_per_commitment"]["masking_commitments"][0]["rows"],
        run["stage3_per_commitment"]["masking_commitments"][0]["rows"], "SAME")
    tb = blk["stage8_plane_index_and_terminals"]["terminal_identity"]
    tr = run["stage8_plane_index_and_terminals"]["terminal_identity"]
    add("slot checks per stage", tb["slot_checks_equal"],
        tr["slot_checks_equal"] // run["stage2_transcript_replay"]["stages"], "SAME")
    s12b, s12r = blk.get("stage12_mask_and_cfs") or {}, run.get("stage12_mask_and_cfs") or {}
    if s12b.get("stages_checked") and s12r.get("stages_checked"):
        add("CFS entries per stage", s12b["entries_recomputed"],
            s12r["entries_recomputed"] // s12r["stages_checked"], "SAME")
    s2b, s2r = blk["stage2_transcript_replay"], run["stage2_transcript_replay"]
    e_out = bpc["E-Output"]["claims"] + bpc["E-Output"]["rows"]
    add("challenges (block) vs run stage 0 + E-Output's lambdas and rows",
        s2b["challenges_checked"], None, "ARITHMETIC")
    rows[-1]["derivation"] = (
        f"one run stage at this shape plus E-Output's {e_out} (1 lambda + "
        f"{bpc['E-Output']['rows']} proximity coefficients); the run's "
        f"{s2r['challenges_checked']} is L stages")
    add("positions", s2b["positions_checked"], s2r["positions_checked"], "ARITHMETIC")
    add("segment position tags", len(s2b["segment_position_tags"]),
        len(s2r["segment_position_tags"]), "NONE")
    s4b, s4r = blk["stage4_the_boundary"], run["stage4_the_boundary"]
    add("boundaries", len(s4b["per_boundary"]), len(s4r["per_boundary"]), "NONE")
    add("whole system", s4b["whole_run"]["matrix"], s4r["whole_run"]["matrix"],
        "ARITHMETIC")
    add("whole system joint", s4b["whole_run"]["joint_fp"],
        s4r["whole_run"]["joint_fp"], "ARITHMETIC")
    add("identified rows", s4b["whole_run"]["identified_rows"],
        s4r["whole_run"]["identified_rows"], "ARITHMETIC")
    s9b, s9r = blk["stage9_hash_layer"], run["stage9_hash_layer"]
    add("openings", s9b["openings"], s9r["openings"], "ARITHMETIC")
    add("channels", blk["stage7_channels"]["counts"],
        run["stage7_channels"]["counts"], "ARITHMETIC")
    rows[-1]["derivation"] = ("the block's table is 10/5/5/8 by construction; "
                              "the 125M run record pins pre-9j bytes and reads "
                              "10/5/4/9 with a dated correction to 10/5/5/8")
    same = [r for r in rows if r["rule"] == "SAME"]
    return {"shape": shape, "rows": rows,
            "same_rows": len(same),
            "same_rows_that_hold": sum(1 for r in same if r["holds"]),
            "same_rows_that_do_not": [r["figure"] for r in same if not r["holds"]]}


def main():
    out = {"what": __doc__.split("\n\n")[0], "per_shape": []}
    for shape, b, r in PAIRS:
        blk, run = load(os.path.join(HERE, b)), load(r)
        if blk is None or run is None:
            out["per_shape"].append({"shape": shape, "skipped": "a record is absent"})
            continue
        c = compare(shape, blk, run)
        out["per_shape"].append(c)
        print(f"{shape}: {c['same_rows_that_hold']} of {c['same_rows']} SAME rows "
              f"hold; do not: {c['same_rows_that_do_not']}")
    with open(os.path.join(HERE, "block_vs_run.json"), "w") as fh:
        json.dump(out, fh, indent=1, sort_keys=True)
        fh.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
