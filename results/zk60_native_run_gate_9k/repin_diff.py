#!/usr/bin/env python3
"""ROUND 9k: what this round's one tool change moved in the records it
re-took, leaf by leaf, with a STRICT list (round 9j's form).

    python3 results/zk60_native_run_gate_9k/repin_diff.py

Every record in `records.txt` is compared with its committed bytes in
`before/` (taken with `git show HEAD:` before any re-take ran).  Each
differing leaf must be one of the changes this round KNOWS it made; anything
else is UNEXPECTED and is the round's result.

  E1  a CHANGED wall clock (`seconds`, `*_seconds`, `seconds_*`);
  E2  the CHANGED `tool_sha256/zk60_native_rg_block.py` -- the one tool
      this round moved;
  E7  in the two rung-G BLOCK records only: a NEW leaf under
      `stage6_negative_controls/C3c_a_blinding_row_shared_between_the_two_external_endpoints/`,
      or the NEW `stage6_negative_controls/controls/[5]` whose value is
      that control's name (appended after C6, so no existing index moves).
"""

from __future__ import annotations

import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
W = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(W, "scripts"))

from zk60_native_rg_recdiff import _walk, diff  # noqa: E402

MOVED_TOOL = "zk60_native_rg_block.py"
C3C = "C3c_a_blinding_row_shared_between_the_two_external_endpoints"
BLOCK_RECORDS = {"zk60_native_run_gate_block/block-rung-g-dense",
                 "zk60_native_run_gate_block/block-rung-g-zero"}


def is_wall_clock(path):
    last = path.rsplit("/", 1)[-1]
    return (last == "seconds" or last.endswith("_seconds")
            or last.startswith("seconds_"))


def classify(record, path, where, value):
    if where == "changed" and is_wall_clock(path):
        return "E1 wall clock"
    if where == "changed" and path == f"tool_sha256/{MOVED_TOOL}":
        return "E2 the one tool this round moved"
    if record in BLOCK_RECORDS and where == "new":
        if path.startswith(f"stage6_negative_controls/{C3C}/"):
            return "E7 control C3c (new)"
        if path == "stage6_negative_controls/controls/[5]" and value == C3C:
            return "E7 control C3c (new)"
    return "UNEXPECTED"


def main():
    with open(os.path.join(HERE, "records.txt")) as fh:
        recs = [x.strip() for x in fh if x.strip()]
    out = {"what": __doc__.split("\n\n")[0], "per_record": [],
           "unexpected": []}
    for p in recs:
        before = os.path.join(HERE, "before", p.replace("/", "_") + ".json")
        after = os.path.join(W, "results", p + ".json")
        with open(before) as fh:
            a = json.load(fh)
        with open(after) as fh:
            b = json.load(fh)
        d = diff(a, b)
        fa, fb = {}, {}
        _walk(a, [], fa)
        _walk(b, [], fb)
        counts = {}
        rows = ([(x, "old", fa.get(x)) for x in d["only_in_the_old_record"]]
                + [(x, "new", fb[x]) for x in d["only_in_the_new_record"]]
                + [(c["path"], "changed", c["new"]) for c in d["changed"]])
        for path, where, val in rows:
            k = classify(p, path, where, val)
            counts[k] = counts.get(k, 0) + 1
            if k == "UNEXPECTED":
                out["unexpected"].append({"record": p, "path": path,
                                          "where": where})
        out["per_record"].append({
            "record": p,
            "identical_leaves": d["identical_leaves"],
            "changed": len(d["changed"]),
            "only_in_the_old_record": len(d["only_in_the_old_record"]),
            "only_in_the_new_record": len(d["only_in_the_new_record"]),
            "by_class": counts,
        })
    out["records"] = len(recs)
    out["identical_leaves_total"] = sum(r["identical_leaves"]
                                        for r in out["per_record"])
    for key in ("changed", "only_in_the_old_record", "only_in_the_new_record"):
        out[f"{key}_total"] = sum(r[key] for r in out["per_record"])
    out["unexpected_count"] = len(out["unexpected"])
    out["no_figure_of_record_moved"] = not out["unexpected"]
    path = os.path.join(HERE, "repin_diff.json")
    with open(path, "w") as fh:
        json.dump(out, fh, indent=1, sort_keys=True)
        fh.write("\n")
    for r in out["per_record"]:
        print(f"{r['record']}: identical {r['identical_leaves']}, "
              f"{r['by_class']}")
    print(f"records {len(recs)}, identical {out['identical_leaves_total']}, "
          f"changed {out['changed_total']}, new "
          f"{out['only_in_the_new_record_total']}, old-only "
          f"{out['only_in_the_old_record_total']}, UNEXPECTED "
          f"{out['unexpected_count']}")
    for u in out["unexpected"][:40]:
        print("  UNEXPECTED", u)
    return 0 if not out["unexpected"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
