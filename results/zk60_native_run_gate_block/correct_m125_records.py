#!/usr/bin/env python3
"""ROUND 9j, J6: the three stale channel texts of the 125M records, corrected
BESIDE what they say (status page `ZK60_SHAPED_PRIVACY_PATH_STATUS.md`
section 4 rows 26-28).

    python3 results/zk60_native_run_gate_block/correct_m125_records.py

WHY A DATED CORRECTION FIELD AND NOT A RE-TAKE.  The 125M records pin the
tool bytes that produced them, deliberately, since round 9c (R9c.8), and a
re-take of `m125-dense-everything` is two and a quarter hours of the heavy
lock.  The channel table is a SUMMARY the tool writes from the stages; none
of the three corrections moves a figure.  So each record keeps every byte it
had and GAINS, beside each stale channel, a `dated_correction_2026_09_23`
member with the text and grade the round-9j tool now emits (commit
1d7cfd2), the evidence re-read this round, and why the record was not
re-taken; and at the top level a `dated_corrections` entry with the counts
as corrected.  The ledger's convention for a document -- a dated block
beside the stale sentence, nothing rewritten -- applied to a record.

The script re-serialises each record with the gate's own settings
(`indent=1, sort_keys=True`, a trailing newline), checks FIRST that this
reproduces the committed bytes exactly, and afterwards that the new record
differs from the old ONLY by added leaves.

Records: every committed record in `results/zk60_native_run_gate_m125/`
whose channel table carries the three texts, EXCEPT `m125-dense-controls.json`,
which is dirty in this worktree with another writer's uncommitted edits and
is not touched (named in the ledger).
"""

from __future__ import annotations

import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
W = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(W, "scripts"))

from zk60_native_rg_recdiff import diff  # noqa: E402
import zk60_native_run_gate as gate  # noqa: E402

D = os.path.join(W, "results", "zk60_native_run_gate_m125")
RECORDS = ("m125-dense-everything", "m125-dense", "m125-zero",
           "m125-dense-full", "m125-zero-full",
           "loader_equivalence_gate_four", "loader_equivalence_gate_five")
NOT_TOUCHED = {"m125-dense-controls": "dirty in this worktree with another "
               "writer's uncommitted edits; not touched"}

SCALE = "the boundary scale tags and the one calibration identity"
REFUSAL = "whether a proof attempt produced a receipt (refusal events)"
JOINT = "the cross-block joint law beyond the linear rank"

EVIDENCE = {
    SCALE: [
        "ZK60_DECISIONS.md D12b(3): 'Interior boundary scales are constants "
        "of the approved calibration: a run refuses any other, so they are "
        "bound through the calibration identity it absorbs' -- built at "
        "lane stage 21 item 3 (71c6509, 2026-09-20 20:16), the register's "
        "own 2026-09-23 status note",
        "run.rs at f4697f9 (this record's capture commit), lines 143-169, "
        "READ 2026-09-23: '**RULING R-5 (register D12b item 3), STAGE 21.**' "
        "and `if *pair != super::ENDPOINT_SCALES` refusing by name in "
        "RunStatement::new",
        "zk60_native_rg_runpins READINGS on run.rs 65d55d25 (round 6): "
        "R-5 is a refusal and nothing else, no absorb added, no proof byte "
        "moved; the record's own run.rs pin f24676c4 was read in round 9",
    ],
    REFUSAL: [
        "ZK60_JOINT_LAW_COMPOSITION_RUN_DISPOSITION.md section 2, ruling "
        "R-2: 'one randomness generator per run is accepted as built ... one "
        "fail-closed entropy point before stage 1 instead of one that can "
        "fail six minutes in'",
        "ZK60_JOINT_SENTENCE_AND_QUERY_CLASSES_DISPOSITION.md J-2: 'a run "
        "uses three (one for the whole run and the two external "
        "endpoints')'",
        "ZK60_HASH_LAYER_AND_FS_LIFT_RUN.md section 6.3: 'three from_os "
        "calls, no seed'",
        "READ 2026-09-23 at f4697f9: run.rs:523, the ONE "
        "ZkRng::from_os(run_seed_domain(profile)) in prove_run, before the "
        "transcript header and the stage loop; boundary.rs:396's from_os is "
        "inside `mod tests` (from :357); endpoint_g.rs:269, one per endpoint",
    ],
    JOINT: [
        "ZK60_JOINT_LAW_COMPOSITION_RUN_DISPOSITION.md section 1: 'Theorem B "
        "is not false ... Its proof is a correct reduction: the toy theorem "
        "per stage, plus one factorisation over stages'; section 2 R-3: 'It "
        "is to be machine-asserted'",
        "ZK60_SHAPED_PRIVACY_PATH_STATUS.md section 2.1 row 4: Theorem B "
        "accepted as a reduction conditional on G-R1, G-R2, G-R4",
        "lane ledger ZK60_BLOCK125M_LANE_PROGRESS.md stage 36, 'The seven "
        "assertions': MEASURED on single-block proofs at six shapes; not at "
        "125M, not at run scope",
    ],
}


def corrected_channels():
    """The three channels exactly as the round-9j tool writes them, taken
    from the tool's own `channels()` over a minimal stand-in, so the text
    here cannot drift from the text a re-take would carry."""
    class _B:
        standalone = False
        stages = []
        run = {"boundary_scales": None}

        class shape:
            opened_cols = 256
            log_cols = 14
            inv_rate = 4
            mask_log_dom = 12

    rec = {
        "stage3_per_commitment": {"per_commitment": []},
        "stage5_zero_data_preimage": {"per_commitment": []},
        "stage8_plane_index_and_terminals": {
            "terminal_identity": {"checked": False}, "channel_status": "open",
            "plane_index": {"present": False}},
        "stage1_integrity": {"distinct_roots_opened": 0},
        "stage2_transcript_replay": {"challenges_checked": 0,
                                     "positions_checked": 0,
                                     "segment_position_tags": []},
        "hash_rule": {"refusals": [], "superseded": False},
    }
    ch = gate.channels(_B(), rec)["channels"]
    return {c["channel"]: c for c in ch if c["channel"] in (SCALE, REFUSAL, JOINT)}


def main():
    now = corrected_channels()
    out = {"records": [], "not_touched": NOT_TOUCHED}
    for name in RECORDS:
        p = os.path.join(D, f"{name}.json")
        with open(p) as fh:
            raw = fh.read()
        r = json.loads(raw)
        if json.dumps(r, indent=1, sort_keys=True) + "\n" != raw:
            raise SystemExit(f"{name}: does not re-serialise byte for byte")
        if "dated_corrections" in r:
            raise SystemExit(f"{name}: already corrected")
        old = json.loads(raw)
        chs = r["stage7_channels"]["channels"]
        counts = dict(r["stage7_channels"]["counts"])
        for c in chs:
            if c["channel"] not in now:
                continue
            n = now[c["channel"]]
            fix = {
                "status_now": n["status"],
                "assumption_now": n["assumption"],
                "text_now": n.get("model_assumption") or n.get("reason"),
                "what_was_stale": n["corrected"],
                "evidence_re_read_2026_09_23": EVIDENCE[c["channel"]],
                "why_the_record_is_not_re_taken": "the 125M records pin the "
                "tool bytes that produced them (round 9c, R9c.8); no figure "
                "of this record moves, and zk60_native_run_gate.py writes "
                "this text natively from round 9j (commit 1d7cfd2)",
            }
            if "ruling_R3_as_of_2026_09_23" in n:
                fix["ruling_R3_as_of_2026_09_23"] = n["ruling_R3_as_of_2026_09_23"]
            c["dated_correction_2026_09_23"] = fix
        as_corrected = dict(counts)
        as_corrected["open"] -= 1
        as_corrected["argued"] = as_corrected.get("argued", 0) + 1
        r["dated_corrections"] = [{
            "date": "2026-09-23",
            "round": "9j (ZK60_NATIVE_RUN_GATE_PROGRESS.md R9j)",
            "source": "ZK60_SHAPED_PRIVACY_PATH_STATUS.md section 4 rows 26-28",
            "channels": [SCALE, REFUSAL, JOINT],
            "counts_of_record": counts,
            "counts_as_corrected": as_corrected,
            "what_moved": "one grade (the scale channel OPEN -> ARGUED on "
            "D12b(3) / ruling R-5) and two reasons; no figure, no stage, no "
            "rank, no control",
            "every_original_byte_is_kept": True,
        }]
        new_raw = json.dumps(r, indent=1, sort_keys=True) + "\n"
        d = diff(old, r)
        if d["changed"] or d["only_in_the_old_record"]:
            raise SystemExit(f"{name}: the correction changed or removed a leaf")
        with open(p, "w") as fh:
            fh.write(new_raw)
        out["records"].append({"record": name, "counts_of_record": counts,
                               "counts_as_corrected": as_corrected,
                               "leaves_added": len(d["only_in_the_new_record"]),
                               "leaves_changed_or_removed": 0,
                               "identical_leaves": d["identical_leaves"]})
        print(f"{name}: {counts} -> {as_corrected}, "
              f"+{len(d['only_in_the_new_record'])} leaves, 0 changed")
    with open(os.path.join(HERE, "m125_records_corrected.json"), "w") as fh:
        json.dump(out, fh, indent=1, sort_keys=True)
        fh.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
