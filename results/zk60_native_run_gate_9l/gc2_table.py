#!/usr/bin/env python3
"""ROUND 9l: ruling GC-2 on every record this round wrote, one table.

    python3 results/zk60_native_run_gate_9l/gc2_table.py

For the thirty re-taken records and the two new 125M block records:
every commitment's sixteen clauses, the per-clause controls (how many, how
many fire, which clauses they exercise, which the OLD weight-level check
accepted), and every u-term the record carries -- the exact figure against
the per-indicator one (the ledger's R9l.2, P-1, P-3, P-4).  Reads records
only; computes nothing about a bundle.
"""

from __future__ import annotations

import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
W = os.path.dirname(os.path.dirname(HERE))
NEW_125M = ["zk60_native_run_gate_9l/block-m125-dense-gc2",
            "zk60_native_run_gate_9l/block-m125-zero-gc2"]


def u_entries(x, path, out):
    if isinstance(x, dict):
        if "u_row_indicators_admissible" in x:
            out.append({"path": path, "exact": x["extra_dimension_beyond_k0"],
                        "per_indicator": x.get("per_indicator_term"),
                        "equal": x.get("per_indicator_equals_exact")})
        elif x.get("u_classes"):
            out.append({"path": path, "exact": x["extra_dimension_beyond_k0"],
                        "per_indicator": x.get("per_indicator_term_fp"),
                        "equal": x.get("per_indicator_equals_exact")})
        for k, v in x.items():
            u_entries(v, f"{path}/{k}", out)
    elif isinstance(x, list):
        for i, v in enumerate(x):
            u_entries(v, f"{path}[{i}]", out)


def row(name, r):
    s3 = r.get("stage3_per_commitment") or {}
    pc = s3.get("per_commitment", [])
    xc = s3.get("exclusivity_controls", {})
    us = []
    u_entries(r, "", us)
    return {
        "record": name,
        "ok": r.get("ok"),
        "stage3_ok": s3.get("ok"),
        "commitments": len(pc),
        "commitments_16_of_16": sum(1 for c in pc
                                    if c.get("exclusivity", {}).get("clauses_passed") == 16),
        "h_pair_true": sum(1 for c in pc if c.get("reduction_hypotheses", {}).get("H-pair")),
        "site_rows_used_exactly_once": {c["role"]: [c["exclusivity"]["site_rows_used_exactly_once"],
                                                    c["exclusivity"]["site_rows"]]
                                        for c in pc if "exclusivity" in c},
        "controls": len(xc.get("controls", {})),
        "controls_firing": sum(1 for c in xc.get("controls", {}).values() if c.get("fires")),
        "clauses_exercised": len(xc.get("clauses_exercised", [])),
        "old_check_accepted": xc.get("the_old_check_accepted"),
        "u_term_entries": len(us),
        "u_terms_exact_equal_per_indicator": sum(1 for u in us if u["equal"] is True),
        "u_term_values": sorted({(u["exact"], u["per_indicator"]) for u in us}),
    }


def main():
    with open(os.path.join(HERE, "records.txt")) as fh:
        names = [x.strip() for x in fh if x.strip()]
    rows = []
    for n in names + NEW_125M:
        p = os.path.join(W, "results", n + ".json")
        if not os.path.exists(p):
            rows.append({"record": n, "present": False})
            continue
        with open(p) as fh:
            rows.append(row(n, json.load(fh)))
    present = [r for r in rows if r.get("present", True)]
    summary = {
        "records": len(present),
        "commitments": sum(r["commitments"] for r in present),
        "commitments_16_of_16": sum(r["commitments_16_of_16"] for r in present),
        "controls": sum(r["controls"] for r in present),
        "controls_firing": sum(r["controls_firing"] for r in present),
        "every_record_exercises_all_16": all(r["clauses_exercised"] == 16 for r in present),
        "u_term_entries": sum(r["u_term_entries"] for r in present),
        "u_terms_exact_equal_per_indicator": sum(r["u_terms_exact_equal_per_indicator"]
                                                 for r in present),
    }
    summary["prediction_held"] = (
        summary["commitments"] == summary["commitments_16_of_16"]
        and summary["controls"] == summary["controls_firing"]
        and summary["every_record_exercises_all_16"]
        and summary["u_term_entries"] == summary["u_terms_exact_equal_per_indicator"]
        and all(r["stage3_ok"] for r in present))
    out = {"what": __doc__.split("\n\n")[0], "rows": rows, "summary": summary}
    with open(os.path.join(HERE, "gc2_table.json"), "w") as fh:
        json.dump(out, fh, indent=1, sort_keys=True)
        fh.write("\n")
    for r in rows:
        if not r.get("present", True):
            print(f"{r['record']}: not in the tree")
            continue
        print(f"{r['record']}: ok {r['ok']}, commitments {r['commitments_16_of_16']}/"
              f"{r['commitments']} at 16 of 16, controls {r['controls_firing']}/{r['controls']}"
              f", clauses {r['clauses_exercised']}, u {r['u_terms_exact_equal_per_indicator']}/"
              f"{r['u_term_entries']} {r['u_term_values']}")
    print(json.dumps(summary))
    return 0 if summary["prediction_held"] else 1


if __name__ == "__main__":
    sys.exit(main())
