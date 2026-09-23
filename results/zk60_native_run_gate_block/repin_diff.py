#!/usr/bin/env python3
"""ROUND 9j: what this round's tools moved in the development records of
record, leaf by leaf, with a STRICT list (round 9i's form, finding R9i-F2).

    python3 results/zk60_native_run_gate_block/repin_diff.py

Every record in `records.txt` is compared with its committed bytes in
`before/` (taken with `git show HEAD:` before the refresh ran).  Each
differing leaf must be one of the changes this round KNOWS it made; anything
else is UNEXPECTED and is the round's result.

  E1  a CHANGED wall clock (`seconds`, `*_seconds`, `seconds_*`);
  E2  a CHANGED `tool_sha256/<t>` for a tool this round moved, or the NEW
      `tool_sha256/zk60_native_rg_block.py`;
  E3  a NEW `.../argument_definitions_this_port_implements/2cee0a2253d6`
      whose value is "repaired" -- the terminal port listing the stage-45
      definition it read;
  E4  a leaf of one of the THREE corrected channels (status page rows
      26-28), found by the channel's NAME in the new record: its `reason`,
      `status` or `assumption` changed, its old `reason` gone (row 26 is now
      ARGUED and carries `model_assumption` instead), or its NEW `corrected`,
      `model_assumption` or `ruling_R3_as_of_2026_09_23`;
  E5  `stage7_channels/counts/argued` +1 and `.../open` -1, exactly -- row
      26's regrade and nothing else;
  E6  `what_it_does_not_show/[i]` changed from EXACTLY "the joint-law
      composition for a run is unwritten" to this round's sentence.
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

MOVED_TOOLS = {
    "zk60_native_run_gate.py", "zk60_native_rg_replay.py",
    "zk60_native_rg_gqa.py", "zk60_native_rg_terminals.py",
    "zk60_native_rg_mask.py", "zk60_native_rg_tcontrols.py",
    "zk60_native_rg_hcontrols.py",
}
NEW_TOOL = "zk60_native_rg_block.py"
CORRECTED = {
    "the boundary scale tags and the one calibration identity",
    "whether a proof attempt produced a receipt (refusal events)",
    "the cross-block joint law beyond the linear rank",
}
OLD_E6 = "the joint-law composition for a run is unwritten"
NEW_E6 = ("the joint LAW (Theorem B) is a reduction accepted on paper, not a "
          "computation of this gate: what is computed is a rank")
RE_CH = re.compile(r"^stage7_channels/channels/\[(\d+)\]/([A-Za-z_0-9]+)$")
RE_E6 = re.compile(r"^what_it_does_not_show/\[\d+\]$")


def is_wall_clock(path):
    last = path.rsplit("/", 1)[-1]
    return (last == "seconds" or last.endswith("_seconds")
            or last.startswith("seconds_"))


def classify(path, where, value, old, corrected_idx):
    if where == "changed" and is_wall_clock(path):
        return "E1 wall clock"
    if path.startswith("tool_sha256/"):
        t = path.split("/", 1)[1]
        if where == "changed" and t in MOVED_TOOLS:
            return "E2 tool hash of a tool this round moved"
        if where == "new" and t == NEW_TOOL:
            return "E2 the new block-layer tool"
    if where == "new" and path.endswith(
            "/argument_definitions_this_port_implements/2cee0a2253d6") \
            and value == "repaired":
        return "E3 the stage-45 argument definition read"
    m = RE_CH.match(path)
    if m and int(m.group(1)) in corrected_idx:
        leaf = m.group(2)
        if where == "changed" and leaf in ("reason", "status", "assumption"):
            return "E4 a corrected channel (rows 26-28)"
        if where == "old" and leaf == "reason":
            return "E4 a corrected channel (rows 26-28)"
        if where == "new" and leaf in ("corrected", "model_assumption",
                                       "ruling_R3_as_of_2026_09_23"):
            return "E4 a corrected channel (rows 26-28)"
    if where == "changed" and path == "stage7_channels/counts/argued" \
            and value == old + 1:
        return "E5 row 26's regrade in the counts"
    if where == "changed" and path == "stage7_channels/counts/open" \
            and value == old - 1:
        return "E5 row 26's regrade in the counts"
    if where == "changed" and RE_E6.match(path) and old == OLD_E6 \
            and value == NEW_E6:
        return "E6 the corrected what-it-does-not-show sentence"
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
        corrected_idx = {
            i for i, c in enumerate(
                (b.get("stage7_channels") or {}).get("channels") or [])
            if c.get("channel") in CORRECTED}
        d = diff(a, b)
        fa, fb = {}, {}
        _walk(a, [], fa)
        _walk(b, [], fb)
        counts = {}
        rows = ([(x, "old", None, fa.get(x)) for x in d["only_in_the_old_record"]]
                + [(x, "new", fb[x], None) for x in d["only_in_the_new_record"]]
                + [(c["path"], "changed", c["new"], c["old"])
                   for c in d["changed"]])
        for path, where, val, old in rows:
            k = classify(path, where, val, old, corrected_idx)
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
