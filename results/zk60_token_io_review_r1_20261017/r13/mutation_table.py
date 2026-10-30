"""Summarise the reviewer's mutation runs (r13/logs/rvtk13-mut-*.log, rvtk13-mut2-*.log).

For each mutant: exit code, passed / failed counts, and the failing tests split into the lane's
tests (classify_tied_tests / classify_cli_tests) and the reviewer's (review_r13_tests).
A mutant is KILLED when at least one test fails. Writes r13/mutation_table.json.
"""
import glob
import json
import os
import re

EV = "/home/victor/IntelligenceRegulation/results/zk60_token_io_review_r1_20261017/r13/logs"
# tests already failing in the unmutated baseline of the same binary are not kills
base = set()
if os.path.exists(f"{EV}/rvtk13-baseline.log"):
    base = set(re.findall(r"^test (\S+) \.\.\. FAILED", open(f"{EV}/rvtk13-baseline.log", errors="replace").read(), re.M))
rows = {"_baseline_failures_excluded": sorted(b.split("::")[-1] for b in base)}
for log in sorted(glob.glob(f"{EV}/rvtk13-mut*.log")):
    name = os.path.basename(log)[len("rvtk13-"):-len(".log")]
    text = open(log, errors="replace").read()
    failed = sorted(set(re.findall(r"^test (\S+) \.\.\. FAILED", text, re.M)) - (base if name.startswith("mut-") else set()))
    res = re.findall(r"^test result: \w+\. (\d+) passed; (\d+) failed; (\d+) ignored", text, re.M)
    done = f"{EV}/rvtk13-{name}.done"
    rows[name] = {
        "exit": open(done).read().strip() if os.path.exists(done) else None,
        "passed_failed_ignored": [list(map(int, r)) for r in res],
        "killed": bool(failed),
        "lane_tests_failing": [f.split("::")[-1] for f in failed if "review_r13_tests" not in f],
        "reviewer_tests_failing": [f.split("::")[-1] for f in failed if "review_r13_tests" in f],
    }
json.dump(rows, open(f"{EV}/../mutation_table.json", "w"), indent=1)
for k, v in rows.items():
    if k.startswith("_"):
        print(k, v)
        continue
    print(f"{k:28s} exit {v['exit']} killed={v['killed']} lane={len(v['lane_tests_failing'])} reviewer={len(v['reviewer_tests_failing'])}")
    print("    lane:", ", ".join(v["lane_tests_failing"]))
    print("    reviewer:", ", ".join(v["reviewer_tests_failing"]))
