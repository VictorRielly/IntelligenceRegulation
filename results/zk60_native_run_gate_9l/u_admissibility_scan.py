#!/usr/bin/env python3
"""ROUND 9l, L1: the basis of the u-term prediction, read from the COMMITTED
records before the exact term ran anywhere.

    python3 results/zk60_native_run_gate_9l/u_admissibility_scan.py

The per-indicator u-term the gate has computed since round 1 solves, for each
zero-sum row u, ONE combination c_u of the generators with c_u Gamma_N = e_u,
and reports rank(xi + K_D) - rank(K_D).  The draft's step 3
(ZK60_GS4_GS5_GS11_GS12_CLOSURES.md §2.2.3, re-derived by the check) shows
that this equals the exact

    u* = rank Gamma_{D u N'} - rank Gamma_{N'} - k0

WHENEVER every indicator e_u is itself reachable: then
W = {c : c Gamma_{N'} = 0} = ker(Gamma_N) + span{c_u}, so W Gamma_D =
K_D + span{xi}.  It can fall short only where some indicator is NOT
reachable (finding F-3's family).  So a record's u-term cannot move under the
exact form if every u-term it carries was computed with every indicator
admissible -- which is what this scan reads, leaf by leaf, from the records
of record (the thirty this round re-takes, plus the 125M block records it
does not).

Nothing here is a privacy property.
"""

from __future__ import annotations

import collections
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
W = os.path.dirname(os.path.dirname(HERE))
RESULTS = os.path.join(W, "results")
RECORDS = os.path.join(RESULTS, "zk60_native_run_gate_9k", "records.txt")
EXTRA = [
    "zk60_native_run_gate_block/block-m125-dense-everything",
    "zk60_native_run_gate_block/block-m125-dense",
    "zk60_native_run_gate_block/block-m125-zero",
    "zk60_native_run_gate_block/block-m125-zero-arms",
    "zk60_native_run_gate_9k/block-m125-dense-c3c",
    "zk60_native_run_gate_9k/block-m125-zero-c3c",
    # the 125M RUN records of round 9 (two-block runs).  `m125-dense-controls`
    # is left out: it carries another writer's uncommitted edits in this
    # worktree, and this round reads only bytes it can name.
    "zk60_native_run_gate_m125/m125-dense",
    "zk60_native_run_gate_m125/m125-zero",
    "zk60_native_run_gate_m125/m125-dense-everything",
    "zk60_native_run_gate_m125/m125-dense-full",
    "zk60_native_run_gate_m125/m125-zero-full",
]


def walk(x, path, out):
    if isinstance(x, dict):
        if "u_row_indicators_admissible" in x:
            out.append({"path": path, "system": "per-commitment",
                        "u_rows": len(x.get("xi_row_weights_nonzero", [])),
                        "admissible": x["u_row_indicators_admissible"],
                        "u_term": x["extra_dimension_beyond_k0"]})
        if "u_classes" in x:
            out.append({"path": path, "system": "joint",
                        "u_rows": x["u_classes"],
                        "admissible": x.get("indicators_admissible", 0),
                        "u_term": x.get("extra_dimension_beyond_k0", 0)})
        for k, v in x.items():
            walk(v, f"{path}/{k}", out)
    elif isinstance(x, list):
        for i, v in enumerate(x):
            walk(v, f"{path}[{i}]", out)


def main():
    with open(RECORDS) as fh:
        recs = [x.strip() for x in fh if x.strip()]
    report = {"what": __doc__.split("\n\n")[0], "per_record": []}
    all_ok = True
    for r in recs + EXTRA:
        p = os.path.join(RESULTS, r + ".json")
        if not os.path.exists(p):
            report["per_record"].append({"record": r, "present": False})
            continue
        with open(p) as fh:
            d = json.load(fh)
        out = []
        walk(d, "", out)
        short = [o for o in out if o["admissible"] != o["u_rows"]]
        all_ok = all_ok and not short
        report["per_record"].append({
            "record": r,
            "present": True,
            "u_term_entries": len(out),
            "entries_with_an_indicator_not_admissible": short,
            "by_kind": {f"{k[0]} u_rows={k[1]} admissible={k[2]} term={k[3]}": v
                        for k, v in sorted(collections.Counter(
                            (o["system"], o["u_rows"], o["admissible"], o["u_term"])
                            for o in out).items())},
        })
    report["records_read"] = sum(1 for x in report["per_record"] if x["present"])
    report["u_term_entries"] = sum(x.get("u_term_entries", 0) for x in report["per_record"])
    report["every_indicator_admissible_everywhere"] = all_ok
    with open(os.path.join(HERE, "u_admissibility_scan.json"), "w") as fh:
        json.dump(report, fh, indent=1, sort_keys=True)
        fh.write("\n")
    for x in report["per_record"]:
        if x["present"]:
            print(f"{x['record']}: {x['u_term_entries']} u-term entries, "
                  f"{len(x['entries_with_an_indicator_not_admissible'])} short, {x['by_kind']}")
        else:
            print(f"{x['record']}: not in the tree")
    print(f"records {report['records_read']}, u-term entries {report['u_term_entries']}, "
          f"every indicator admissible everywhere: {all_ok}")
    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main())
