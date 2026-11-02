#!/usr/bin/env python3
"""TS / CENSUS lane (2026-11-02): section 3's table. Per base: the L = 3 bundle's parameter-line length and boundary
rows, and the `parameters` absorb data lengths the s25 W-2 printout lists for that run profile (in printout order).
Usage: param_lengths.py <printout>"""
import json
import re
import sys

B = {"rung": "/Users/victorrielly/zk60-artifacts/d60_20261102/pg_bundles_r26/d55-r13_rung_h24-s0",
     "8b": "/Users/victorrielly/zk60-artifacts/d60_20261102/pg_bundles_r26/d55-r13_8b_t128_h24-s0",
     "tiny": "/Users/victorrielly/zk60-artifacts/d60_20261102/pg_bundles_bases/d55-r13_tiny_t128_low-s0",
     "shield128": "/Users/victorrielly/zk60-artifacts/d60_20261102/pg_bundles_bases/d55-r13_shield_t128_h24-s0",
     "shield256": "/Users/victorrielly/zk60-artifacts/d60_20261102/pg_bundles_bases/d55-r13_shield_t256_h24-s0"}
txt = open(sys.argv[1], encoding="utf-8", errors="replace").read().split("\n")
for k, d in B.items():
    r = json.load(open(d + "/run.json"))
    line = r["parameter_line"]
    rows = re.search(r"-rows(\d+)-sites", line).group(1)
    prof = r["profile"]
    lens, cur = [], False
    for ln in txt:
        if ln.startswith("--- "):
            cur = ln.startswith(f"--- {prof} (")
            continue
        if cur and "`parameters`" in ln:
            lens.append(int(re.search(r"with (\d+) bytes", ln).group(1)))
    print(f"{k}: L = {r['blocks']} line {len(line)} B, boundary rows {rows}; s25 lists {sorted(set(lens))} ({len(lens)} entries)")
