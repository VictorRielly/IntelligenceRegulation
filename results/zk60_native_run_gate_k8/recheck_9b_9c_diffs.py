#!/usr/bin/env python3
"""ROUND 9i, finding R9i-F2: the committed leaf diffs of rounds 9b and 9c,
re-read with a STRICT reading of the stages the leaf classifier grades
wholesale.

    python3 results/zk60_native_run_gate_k8/recheck_9b_9c_diffs.py

`zk60_native_rg_recclass` puts ANY path under `stage8_…` in its round-3
class "the new fields about captured public tables", and ANY path under
stages 9, 10, 11, 12 and 13 in the class of the round that added the stage.
So its "0 UNCLASSIFIED" would not have reported a moved slot check, group
count, hash-layer figure, preimage or mask figure.  This script takes the
diffs those rounds committed (`results/zk60_native_run_gate_p2/diffs/`,
`results/zk60_native_run_gate_9c/diffs2/`) and lists every leaf under
stages 7-13 that is NOT one of:

  * a changed wall clock (`seconds`, `*_seconds`, `seconds_*`);
  * control CT-9, appended by round 9b (`stage8_…/controls/controls/[8]/…`);
  * the terminal port's list of `argument.rs` definitions gaining an entry.

An empty residue means those rounds' "nothing measured moved" holds under
the strict reading too.  It reads committed files only.
"""

import glob
import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
W = os.path.dirname(os.path.dirname(HERE))
DIRS = ("results/zk60_native_run_gate_p2/diffs",
        "results/zk60_native_run_gate_9c/diffs2")
STAGE = re.compile(r"^stage(7|8|9|10|11|12|13)_")


def wall(p):
    last = p.rsplit("/", 1)[-1]
    return last == "seconds" or last.endswith("_seconds") or last.startswith("seconds_")


CT_ENTRY = re.compile(
    r"^stage8_plane_index_and_terminals/controls/controls/\[(\d+)\]/")


def _record_of(diff_name):
    """The committed record (post-9c bytes, `before/` of this round) a diff
    file is about, so an appended control can be identified BY NAME."""
    if diff_name.startswith("pre-"):
        d, b = "zk60_native_run_gate_preimage", diff_name[4:]
    elif diff_name.startswith("mask-"):
        d, b = "zk60_native_run_gate_mask", diff_name[5:]
    else:
        hits = [f for f in glob.glob(os.path.join(HERE, "before", "*.json"))
                if f.endswith("_" + diff_name + ".json")
                and "_preimage_" not in f and "_mask_" not in f]
        return hits[0] if len(hits) == 1 else None
    return os.path.join(HERE, "before", f"{d}_{b}.json")


_cache = {}


def _control_name(diff_name, k):
    path = _record_of(diff_name)
    if path is None or not os.path.exists(path):
        return None
    if path not in _cache:
        with open(path) as fh:
            _cache[path] = json.load(fh)
    try:
        return _cache[path]["stage8_plane_index_and_terminals"]["controls"][
            "controls"][k]["control"]
    except (KeyError, IndexError, TypeError):
        return None


def allowed(p, where, diff_name):
    if where == "chg" and wall(p):
        return "wall clock"
    m = CT_ENTRY.match(p)
    if where == "new" and m and _control_name(diff_name, int(m.group(1))) == "CT-9":
        return "CT-9 appended (round 9b), identified by name"
    if where == "new" and "/argument_definitions_this_port_implements/" in p:
        return "a definition digest listed"
    return None


def main():
    total, residue, by = 0, [], {}
    for d in DIRS:
        for f in sorted(glob.glob(os.path.join(W, d, "*.diff.json"))):
            with open(f) as fh:
                x = json.load(fh)
            rows = ([(p, "old") for p in x["only_in_the_old_record"]]
                    + [(p, "new") for p in x["only_in_the_new_record"]]
                    + [(c["path"], "chg") for c in x["changed"]])
            for p, where in rows:
                if not STAGE.match(p):
                    continue
                total += 1
                k = allowed(p, where,
                            os.path.basename(f).replace(".diff.json", ""))
                if k is None:
                    residue.append(f"{d}/{os.path.basename(f)}: {where} {p}")
                else:
                    by[k] = by.get(k, 0) + 1
    print(f"leaves under stages 7-13 in the committed 9b / 9c diffs: {total}")
    for k, v in sorted(by.items()):
        print(f"  {k}: {v}")
    print(f"RESIDUE (a measured figure that moved): {len(residue)}")
    for r in residue[:50]:
        print("  ", r)
    return 0 if not residue else 1


if __name__ == "__main__":
    raise SystemExit(main())
