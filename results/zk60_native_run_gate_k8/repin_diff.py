#!/usr/bin/env python3
"""ROUND 9i: what the re-pin moved, leaf by leaf, with a STRICT list.

    python3 results/zk60_native_run_gate_k8/repin_diff.py

Every record in `records.txt` is compared with its committed bytes in
`before/` (taken with `git show HEAD:` before the refresh ran), using
`zk60_native_rg_recdiff`'s walk.  Each differing leaf must be one of the
changes this round KNOWS it made; anything else is UNEXPECTED and is the
round's result.

Why not `zk60_native_rg_recclass`: its round-3 class is "any path under
`stage8_plane_index_and_terminals`", and rounds 4 / 7 / 8 add classes for
the whole of stages 10, 11, 12 and 13 -- so a moved SLOT CHECK or a moved
group count would be classified there, not reported.  That is finding
R9i-F2; this script is the stricter reading, and it is what the ledger
quotes.

The expected changes, and nothing else:

  E1  a CHANGED wall clock: `seconds`, or a named timer ending `_seconds`
      or starting `seconds_`, at any depth (a new or vanished one is not);
  E2  `tool_sha256/<t>` for the five tools this round moved;
  E3  `run_layer_source_pins/per_file/[i]/lane_commits/[j]` or
      `.../bundles_written_at_them/[j]` ONLY IN THE NEW RECORD, whose value
      is the rung-K8 capture commit or a rung-K8 bundle name -- the
      run-layer pin table naming the new commit on a digest that did not
      move;
  E4  `.../source_pins/argument_definitions_this_port_implements/f7fa2ad4213d`
      ONLY IN THE NEW RECORD, value "repaired" -- the terminal port listing
      the definitions it has read.
"""

from __future__ import annotations

import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
W = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(W, "scripts"))

from zk60_native_rg_recdiff import diff  # noqa: E402

MOVED_TOOLS = {
    "zk60_native_rg_gqa.py", "zk60_native_rg_terminals.py",
    "zk60_native_rg_mask.py", "zk60_native_rg_runpins.py",
    "zk60_native_rg_gcontrols.py",
}
K8_COMMIT = "99a8de832a6322c94bf951f0f443b96e1dc63cb8"
K8_BUNDLES = {"run-s-dense-k8", "run-t-zero-k8"}
RE_E3 = re.compile(r"^run_layer_source_pins/per_file/\[\d+\]/"
                   r"(lane_commits|bundles_written_at_them)/\[\d+\]$")


def is_wall_clock(path):
    """`seconds` itself, or a named timer such as stage 11's
    `layout_seconds` / `verification/seconds_opened_columns`."""
    last = path.rsplit("/", 1)[-1]
    return (last == "seconds" or last.endswith("_seconds")
            or last.startswith("seconds_"))


def classify(path, where, value):
    if where == "changed" and is_wall_clock(path):
        return "E1 wall clock"
    if where == "changed" and path.startswith("tool_sha256/") \
            and path.split("/", 1)[1] in MOVED_TOOLS:
        return "E2 tool hash of a tool this round moved"
    if where == "new" and RE_E3.match(path) \
            and (value == K8_COMMIT or value in K8_BUNDLES):
        return "E3 the run-layer pin table names the rung-K8 commit/bundles"
    if where == "new" and path.endswith(
            "/source_pins/argument_definitions_this_port_implements/"
            "f7fa2ad4213d") and value == "repaired":
        return "E4 the terminal port lists the definition it read at f7fa2ad4"
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
        fb = {}
        # values of the new-only leaves, for E3 / E4
        from zk60_native_rg_recdiff import _walk
        _walk(b, [], fb)
        counts = {}
        rows = ([(x, "old", None) for x in d["only_in_the_old_record"]]
                + [(x, "new", fb[x]) for x in d["only_in_the_new_record"]]
                + [(c["path"], "changed", c["new"]) for c in d["changed"]])
        for path, where, val in rows:
            k = classify(path, where, val)
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
    out["unexpected_count"] = len(out["unexpected"])
    out["no_figure_of_record_moved"] = not out["unexpected"]
    path = os.path.join(HERE, "repin_diff.json")
    with open(path, "w") as fh:
        json.dump(out, fh, indent=1, sort_keys=True)
        fh.write("\n")
    for r in out["per_record"]:
        print(f"{r['record']}: identical {r['identical_leaves']}, "
              f"{r['by_class']}")
    print(f"records {len(recs)}, UNEXPECTED {out['unexpected_count']}")
    for u in out["unexpected"][:40]:
        print("  UNEXPECTED", u)
    return 0 if not out["unexpected"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
