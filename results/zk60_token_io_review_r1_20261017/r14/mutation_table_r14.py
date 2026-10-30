#!/usr/bin/env python3
"""Reviewer mutation table for the token round-14 review.

A mutant is KILLED when a test that passed in the baseline run fails under it.
Reads r14/logs/rvtk14-baseline.log and rvtk14-mut-<m>.log; writes
r14/mutation_table_r14.json and prints a table.
"""
import json, os, re

EV = os.path.join(os.path.dirname(os.path.abspath(__file__)), "logs")
MUTANTS = ["n2", "pad", "bind", "src", "check-tables", "n-free", "size-from-n", "vr-last", "replay", "empty"]


def outcomes(path):
    t = open(path, errors="replace").read()
    res = {}
    for m in re.finditer(r"^test (\S+) \.\.\. (ok|FAILED|ignored)", t, re.M):
        res[m.group(1)] = m.group(2)
    tr = re.findall(r"test result: (\w+)\. (\d+) passed; (\d+) failed; (\d+) ignored", t)
    return res, tr


base, btr = outcomes(os.path.join(EV, "rvtk14-baseline.log"))
ok = {k for k, v in base.items() if v == "ok"}
table = {"baseline": {"result": btr, "ok": len(ok)}, "mutants": {}}
for m in MUTANTS:
    p = os.path.join(EV, f"rvtk14-mut-{m}.log")
    if not os.path.exists(p):
        table["mutants"][m] = {"missing": True}
        continue
    r, tr = outcomes(p)
    killers = sorted(k for k in ok if r.get(k) == "FAILED")
    lane = [k.split("::")[-1] for k in killers if "review_r14_tests" not in k]
    mine = [k.split("::")[-1] for k in killers if "review_r14_tests" in k]
    table["mutants"][m] = {"result": tr, "killed": bool(killers), "lane_killers": lane, "reviewer_killers": mine}
json.dump(table, open(os.path.join(os.path.dirname(EV), "mutation_table_r14.json"), "w"), indent=1)
print("baseline", btr, "ok", len(ok))
for m, d in table["mutants"].items():
    if d.get("missing"):
        print(f"{m:14s} MISSING")
        continue
    print(f"{m:14s} {'KILLED' if d['killed'] else 'SURVIVED':8s} lane {len(d['lane_killers'])}: {', '.join(d['lane_killers'])[:200]}")
    print(f"{'':14s} {'':8s} mine {len(d['reviewer_killers'])}: {', '.join(d['reviewer_killers'])}")
