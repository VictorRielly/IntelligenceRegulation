#!/usr/bin/env python3
"""Round 9d, task T3: the same leaf diff for the native joint-view record.

    python3 results/zk60_native_d22_replay_20260922/leafdiff_jv.py \
        <new joint_view.json> [<record of record>]

The joint-view record keeps a `per_capture` list under each stage rather than
one list of captures, so the A/B/N comparison of `leafdiff.py` is done stage by
stage: A and B are the two block captures of the record of record, N is the new
bundle's single entry, and a leaf that is the same on A and B but different on
N is a figure of record moving.
"""
import json
import sys

from leafdiff import paths  # noqa: E402  (same directory)

STAGES = ["stage1_transcript_replay", "stage2_commitment_side_joint_view",
          "stage3_masking_commitment_view", "stage4_stacked",
          "stage5_zero_witness_gate", "stage7_terminal_polynomial_port"]
BLOCK = "private-block"


def block_indices(rec):
    return [i for i, c in enumerate(rec["captures"]) if BLOCK in c["profile"]]


def main():
    new_path = sys.argv[1]
    rr_path = (sys.argv[2] if len(sys.argv) > 2 else
               "/home/victor/wt-zk60-jointview/results/zk60_native_joint_view/joint_view.json")
    new = json.load(open(new_path))
    rr = json.load(open(rr_path))
    print(f"new    : {new_path}")
    print(f"record : {rr_path}")
    print()

    print("== 1. the record, outside the per-capture lists ==")
    def strip(rec):
        out = {}
        for k, v in rec.items():
            if k in ("seconds", "captures_dir", "manifest", "captures"):
                continue
            if isinstance(v, dict) and "per_capture" in v:
                out[k] = {kk: vv for kk, vv in v.items() if kk != "per_capture"}
            else:
                out[k] = v
        return out
    _, rows = paths(strip(rr), strip(new))
    rows = [r for r in rows if "/seconds" not in r[0]]
    if not rows:
        print("identical at every leaf (version, ok, the ten tool hashes, every "
              "stage's own verdict and every whole-gate control)")
    for p, x, y in rows:
        print(f"  {p}\n    record {x}\n    new    {y}")
    print()
    print(f"seconds, record {rr['seconds']}   new {new['seconds']}")
    print(f"manifest, record : {json.dumps(rr['manifest'], sort_keys=True)}")
    print(f"manifest, new    : {json.dumps(new['manifest'], sort_keys=True)}")
    print(f"captures, new    : {json.dumps(new['captures'], sort_keys=True)}")
    print()

    ia, ib = block_indices(rr)
    inew = block_indices(new)
    assert len(inew) == 1
    ni = inew[0]
    print(f"A = {rr['captures'][ia]['proof_sha256'][:16]}   "
          f"B = {rr['captures'][ib]['proof_sha256'][:16]}   "
          f"N = {new['captures'][ni]['proof_sha256'][:16]}")
    print()
    print("== 2. stage by stage ==")
    total_moved = 0
    for st in STAGES:
        if st not in rr or "per_capture" not in rr[st]:
            continue
        A = rr[st]["per_capture"][ia]
        B = rr[st]["per_capture"][ib]
        N = new[st]["per_capture"][ni]
        drop = {"capture", "proof_sha256", "seconds"}
        A = {k: v for k, v in A.items() if k not in drop}
        B = {k: v for k, v in B.items() if k not in drop}
        N = {k: v for k, v in N.items() if k not in drop}
        ab, _ = paths(A, B)
        an, an_rows = paths(A, N)
        bn, _ = paths(B, N)
        moved = sorted((an & bn) - ab)
        total_moved += len(moved)
        print(f"{st}: A/B {len(ab)} leaves differ, A/N {len(an)}, B/N {len(bn)}, "
              f"MOVED {len(moved)}")
        by = {p: (x, y) for p, x, y in an_rows}
        for p in moved:
            x, y = by.get(p, ("?", "?"))
            print(f"    {p}\n      record (A and B) {x}\n      new              {y}")
    print()
    print(f"== 3. FIGURES THAT MOVED, all stages: {total_moved} ==")
    print()
    print("== 4. the stage verdicts and the named figures ==")
    for st in STAGES + ["stage6_negative_controls"]:
        if st in new:
            print(f"  {st:40} ok={new[st]['ok']}")
    print(f"  {'whole gate':40} ok={new['ok']}  "
          f"privacy_property_established={new['privacy_property_established']}")
    return 1 if total_moved else 0


if __name__ == "__main__":
    raise SystemExit(main())
