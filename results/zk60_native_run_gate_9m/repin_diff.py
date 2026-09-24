#!/usr/bin/env python3
"""ROUND 9m: what this round's tool change moved in the records it re-took,
leaf by leaf, with a STRICT list (rounds 9j-9l's form).

    python3 results/zk60_native_run_gate_9m/repin_diff.py

Every record in `records.txt` is compared with its committed bytes in
`before/` (taken with `git show HEAD:` before any re-take ran).  Each
differing leaf must be one of the changes this round KNOWS it made (the
ledger's R9m.4); anything else is UNEXPECTED and is the round's result.

  E1  a CHANGED wall clock (`seconds`, `*_seconds`, `seconds_*`);
  E2  `tool_sha256/` of the two tools this round edited (CHANGED):
      `zk60_native_rg_bundle.py` and `zk60_native_rg_runpins.py`;
  E3  a NEW element of a run-layer pin's `lane_commits` or
      `bundles_written_at_them` list, whose value is the twelve-block capture
      commit `17830dc...` or one of the two twelve-block bundles -- the
      entries of `run_capture.rs` (`d09f3853`) and `boundary.rs`
      (`5b1c85fe`) gained them, and only records of bundles pinned at those
      digests show it.

The validation / `run/` reader adds no leaf to a bundle that carries
neither, and no bundle of the thirty does, so a new `validation_file` or
`run_directory` leaf would be UNEXPECTED; so would any changed rank,
disclosed dimension, challenge, slot check, control, preimage, mask or
channel figure.
"""

from __future__ import annotations

import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
W = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(W, "scripts"))

from zk60_native_rg_recdiff import _walk, diff  # noqa: E402

CHANGED_TOOLS = {"zk60_native_rg_bundle.py", "zk60_native_rg_runpins.py"}
NEW_TOOLS: set = set()
PIN_LIST = re.compile(
    r"^run_layer_source_pins/per_file/\[\d+\]/(lane_commits|bundles_written_at_them)/\[\d+\]$")
NEW_PIN_VALUES = {"17830dcc9f24b0d19e212b0344476e299cfd9be0",
                  "m125-capture-dense-l12", "m125-capture-zero-l12"}


def is_wall_clock(path):
    last = path.rsplit("/", 1)[-1]
    return (last == "seconds" or last.endswith("_seconds")
            or last.startswith("seconds_"))


def classify(path, where, new_value=None):
    if where == "changed" and is_wall_clock(path):
        return "E1 wall clock"
    if path.startswith("tool_sha256/"):
        t = path.split("/", 1)[1]
        if where == "changed" and t in CHANGED_TOOLS:
            return "E2 a tool this round edited"
    if where == "new" and PIN_LIST.match(path) and new_value in NEW_PIN_VALUES:
        return "E3 a run-layer pin entry gained 17830dc / a twelve-block bundle"
    return "UNEXPECTED"


def main():
    with open(os.path.join(HERE, "records.txt")) as fh:
        recs = [x.strip() for x in fh if x.strip()]
    out = {"what": __doc__.split("\n\n")[0], "per_record": [], "unexpected": []}
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
        rows = ([(x, "old") for x in d["only_in_the_old_record"]]
                + [(x, "new") for x in d["only_in_the_new_record"]]
                + [(c["path"], "changed") for c in d["changed"]])
        for path, where in rows:
            k = classify(path, where, fb.get(path))
            counts[k] = counts.get(k, 0) + 1
            if k == "UNEXPECTED":
                out["unexpected"].append({
                    "record": p, "path": path, "where": where,
                    "old": fa.get(path), "new": fb.get(path)})
        out["per_record"].append({
            "record": p,
            "identical_leaves": d["identical_leaves"],
            "changed": len(d["changed"]),
            "only_in_the_old_record": len(d["only_in_the_old_record"]),
            "only_in_the_new_record": len(d["only_in_the_new_record"]),
            "by_class": counts,
        })
    out["records"] = len(recs)
    out["identical_leaves_total"] = sum(r["identical_leaves"] for r in out["per_record"])
    for key in ("changed", "only_in_the_old_record", "only_in_the_new_record"):
        out[f"{key}_total"] = sum(r[key] for r in out["per_record"])
    totals = {}
    for r in out["per_record"]:
        for k, v in r["by_class"].items():
            totals[k] = totals.get(k, 0) + v
    out["by_class_total"] = totals
    out["unexpected_count"] = len(out["unexpected"])
    out["no_figure_of_record_moved"] = not out["unexpected"]
    with open(os.path.join(HERE, "repin_diff.json"), "w") as fh:
        json.dump(out, fh, indent=1, sort_keys=True)
        fh.write("\n")
    for r in out["per_record"]:
        print(f"{r['record']}: identical {r['identical_leaves']}, {r['by_class']}")
    print(f"records {len(recs)}, identical {out['identical_leaves_total']}, "
          f"changed {out['changed_total']}, new {out['only_in_the_new_record_total']}, "
          f"old-only {out['only_in_the_old_record_total']}, UNEXPECTED "
          f"{out['unexpected_count']}")
    print(f"by class: {totals}")
    for u in out["unexpected"][:40]:
        print("  UNEXPECTED", u)
    return 0 if not out["unexpected"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
