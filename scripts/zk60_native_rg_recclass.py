#!/usr/bin/env python3
"""**"Nothing measured about the old bundles moved", as a computed
statement.**

    python3 scripts/zk60_native_rg_recclass.py D1.json D2.json ... --out S.json

Each input is a diff produced by `zk60_native_rg_recdiff.py` between a
round-2 record and the same bundle's round-3 record.  Every differing leaf
is put in exactly one CLASS, and a leaf that fits no class is reported
UNCLASSIFIED -- which is the only interesting outcome, because the classes
are the changes round 3 knows it made:

  * a wall clock or a tool SHA-256;
  * the two NEW record blocks, `hash_rule` and `stage9_hash_layer`;
  * the replay naming the rule it computed under;
  * the fields stage 8 gained about CAPTURED public tables (empty on a
    bundle that carries none);
  * the reworded OPEN reason of the eleven table-bearing slots;
  * the insertion of ONE channel entry, which shifts every later index.

Anything else -- a rank, a disclosed dimension, a challenge count, a slot
check, a control figure -- would be UNCLASSIFIED, and the summary says so
rather than grading it away.  This tool grades nothing else.
"""

from __future__ import annotations

import argparse
import json
import os

CLASSES = (
    (lambda p: p == "seconds" or p.endswith("/seconds"), "wall clock"),
    (lambda p: p.startswith("tool_sha256"), "tool hashes"),
    (lambda p: p == "hash_rule" or p.startswith("hash_rule/")
     or "/hash_rule/" in p and p.startswith("stage1_integrity"),
     "the new hash_rule block"),
    (lambda p: p.startswith("stage9_hash_layer"), "the new stage 9 block"),
    (lambda p: p == "stage2_transcript_replay/hash_rule",
     "the replay now names the rule it computed under"),
    (lambda p: p.startswith("stage7_channels/channels/"),
     "the channel array (one entry inserted; every later index shifts)"),
    (lambda p: p.startswith("stage7_channels/"),
     "the channel counts (one entry added)"),
    (lambda p: p.startswith("what_it_does_not_show"),
     "the what-it-does-not-show wording"),
    (lambda p: "/open_slots/" in p and p.endswith("/reason"),
     "the eleven OPEN slots' reason, reworded"),
    (lambda p: p.startswith("stage8_plane_index_and_terminals")
     or "/per_slot_terminal_check/" in p,
     "the new fields about captured public tables"),
)

NOTE = (
    "every difference is one of: a wall clock, a tool SHA-256, the two NEW "
    "record blocks (hash_rule and stage 9), the replay naming its rule, the new "
    "fields about captured public tables (empty on a bundle that carries none), "
    "the reworded OPEN reason of the eleven slots, or the insertion of ONE "
    "channel entry, which shifts every later entry's index.  No rank, disclosed "
    "dimension, challenge count, slot check or control figure differs."
)


def classify(path: str) -> str:
    for test, name in CLASSES:
        if test(path):
            return name
    return "UNCLASSIFIED"


def summarise(diffs: dict) -> dict:
    out = {
        "what": "the superseded bundles re-run under round 3 and diffed leaf by "
        "leaf against their round-2 records",
        "note": NOTE,
        "per_bundle": [],
        "unclassified": [],
    }
    for name, d in diffs.items():
        counts: dict = {}
        for p in (d["only_in_the_old_record"] + d["only_in_the_new_record"]
                  + [c["path"] for c in d["changed"]]):
            k = classify(p)
            counts[k] = counts.get(k, 0) + 1
            if k == "UNCLASSIFIED":
                out["unclassified"].append({"bundle": name, "path": p})
        out["per_bundle"].append({
            "bundle": name,
            "identical_leaves": d["identical_leaves"],
            "changed": len(d["changed"]),
            "only_in_the_old_record": len(d["only_in_the_old_record"]),
            "only_in_the_new_record": len(d["only_in_the_new_record"]),
            "by_class": counts,
        })
    out["no_measured_figure_moved"] = not out["unclassified"]
    return out


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("diffs", nargs="+")
    ap.add_argument("--out")
    args = ap.parse_args(argv)
    diffs = {}
    for p in args.diffs:
        with open(p) as fh:
            diffs[os.path.basename(p).replace(".diff.json", "")] = json.load(fh)
    s = summarise(diffs)
    text = json.dumps(s, indent=1, sort_keys=True)
    if args.out:
        with open(args.out, "w") as fh:
            fh.write(text + "\n")
        print(f"{args.out}: {len(s['per_bundle'])} bundles, "
              f"{len(s['unclassified'])} unclassified leaves")
    else:
        print(text)
    return 0 if s["no_measured_figure_moved"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
