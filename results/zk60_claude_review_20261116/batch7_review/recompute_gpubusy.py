#!/usr/bin/env python3
"""Batch 7 review: steady-state GPU busy union per request, anchored differently from the author (read-only).
Anchor: the pass starts at (first witness command buffer begin of request 0) minus the median bookend-before-first-QKV (about 0.02 s, ignored);
window = [t0 + result(0), t0 + result(R-1)] from the log.  Run: python3 -I recompute_gpubusy.py"""
import gzip, re, statistics as st
from pathlib import Path
D = Path("/Users/victorrielly/IntelligenceRegulation/results/zk60_batch7_sealing_lanes3_20261117")
T = Path("/Users/victorrielly/zk60-artifacts/batch7_traces_20261117")
ARMS = {"serve4": ("serve4_lanes2_6warm.15818.tsv.gz", "batch7_serve4_lanes2_6warm.log", 4), "serve6": ("serve6_lanes3_6warm.16734.tsv.gz", "batch7_serve6_lanes3_6warm.log", 6)}
RES = re.compile(r"\[(serve[^\]]+)\] pass (\d+) request (\d+): .*?result ([0-9.]+);")
def union(iv, lo, hi):
    ev = []
    for a, b in iv:
        a, b = max(a, lo), min(b, hi)
        if b > a: ev += [(a, 1), (b, -1)]
    ev.sort(key=lambda e: (e[0], -e[1])); dep = 0; last = 0; tot = 0.0
    for t, d in ev:
        if dep > 0: tot += t - last
        dep += d; last = t
    return tot
for arm, (gz, lg, R) in ARMS.items():
    rows = []
    with gzip.open(T / gz, "rt") as f:
        for l in f:
            p = l.rstrip("\n").split("\t")
            if p[0] == "tag" or len(p) != 9: continue
            rows.append((p[0], p[1], float(p[4]), float(p[6]), float(p[7]), float(p[8])))
    wp = sorted([r for r in rows if r[0] == "wprod" and r[1].startswith("t=128")], key=lambda r: r[2])
    wp = wp[len(wp) - 224 * (1 + 6 * R):]
    iv = [(r[3], r[4]) for r in rows if r[3] > 0 and r[4] >= r[3]]
    res = {}
    for m in RES.finditer((D / lg).read_text()):
        res[(int(m.group(2)), int(m.group(3)))] = float(m.group(4))
    out = []; pct = []
    for p in range(6):
        i = 1 + p * R
        t0 = min(r[2] for r in wp[224 * i:224 * i + 3])
        lo, hi = t0 + res[(p, 0)], t0 + res[(p, R - 1)]
        u = union(iv, lo, hi)
        out.append(u / (R - 1)); pct.append(100 * u / (hi - lo))
    print(arm, "GPU busy union per steady request (s):", [round(x, 3) for x in out], "median", round(st.median(out), 4), "| % of window median", round(st.median(pct), 2))
print("report: serve4 2.6494 s (71.96%), serve6 2.6823 s (71.22%)")
