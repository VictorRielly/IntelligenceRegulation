#!/usr/bin/env python3
"""ROUND 9l: what this round's tool change moved in the records it re-took,
leaf by leaf, with a STRICT list (rounds 9j / 9k's form).

    python3 results/zk60_native_run_gate_9l/repin_diff.py

Every record in `records.txt` is compared with its committed bytes in
`before/` (taken with `git show HEAD:` before any re-take ran).  Each
differing leaf must be one of the changes this round KNOWS it made (the
ledger's R9l.2, P-5); anything else is UNEXPECTED and is the round's result.

  E1  a CHANGED wall clock (`seconds`, `*_seconds`, `seconds_*`);
  E2  `tool_sha256/` of the three tools this round edited (CHANGED) and of
      the one it added (NEW);
  E3  a NEW leaf under a per-commitment `exclusivity` block (stage 3);
  E4  a NEW leaf under `stage3_per_commitment/exclusivity_controls/`;
  E5  a NEW leaf of a `u_row_term` (per commitment) or `u_row_detail`
      (joint) block named in `U_NEW` -- the exact term's two ranks and form,
      the per-indicator figure beside it, and whether the two agree.

A CHANGED u-term value, rank, part, joint, control figure or anything else
is not in the list, so it would be UNEXPECTED.
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

CHANGED_TOOLS = {"zk60_native_run_gate.py", "zk60_native_rg_pcs.py",
                 "zk60_native_rg_joint.py"}
NEW_TOOLS = {"zk60_native_rg_exclusivity.py"}
U_NEW = {"exact_form", "rank_gamma_on_data_and_n_prime", "rank_gamma_on_n_prime",
         "per_indicator_term", "per_indicator_term_fp", "per_indicator_equals_exact"}
PER_COMMITMENT_EX = re.compile(r"^stage3_per_commitment/per_commitment/\[\d+\]/exclusivity/")


def is_wall_clock(path):
    last = path.rsplit("/", 1)[-1]
    return (last == "seconds" or last.endswith("_seconds")
            or last.startswith("seconds_"))


def classify(path, where):
    if where == "changed" and is_wall_clock(path):
        return "E1 wall clock"
    if path.startswith("tool_sha256/"):
        t = path.split("/", 1)[1]
        if where == "changed" and t in CHANGED_TOOLS:
            return "E2 a tool this round edited"
        if where == "new" and t in NEW_TOOLS:
            return "E2 the tool this round added"
    if where == "new" and PER_COMMITMENT_EX.match(path):
        return "E3 per-commitment exclusivity (new)"
    if where == "new" and path.startswith("stage3_per_commitment/exclusivity_controls/"):
        return "E4 the exclusivity controls (new)"
    if where == "new":
        parts = path.split("/")
        if len(parts) >= 2 and parts[-2] in ("u_row_term", "u_row_detail") \
                and parts[-1] in U_NEW:
            return "E5 the exact u-term's detail (new)"
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
            k = classify(path, where)
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
