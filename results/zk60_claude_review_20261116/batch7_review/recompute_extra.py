#!/usr/bin/env python3
"""Batch 7 review: extra checks (standard library only, read-only).  Run: python3 -I recompute_extra.py
 1. Section 4 per-slot spans with request windows cut at each request's first witness command buffer.
 2. Overlap decomposition shares on MEANS (which add exactly) as well as medians.
 3. Share of each request's sealing chain that has a prover command buffer executing beside it, per arm and position.
 4. Spread of the three-lane S_ov per position.
"""
import gzip
import re
import statistics as st
from pathlib import Path

T = Path("/Users/victorrielly/zk60-artifacts/batch7_traces_20261117")


def load(path):
    rows = []
    with gzip.open(path, "rt") as f:
        for line in f:
            p = line.rstrip("\n").split("\t")
            if p[0] == "tag" or len(p) != 9:
                continue
            rows.append(dict(tag=p[0], detail=p[1], b=float(p[4]), c=float(p[5]), gs=float(p[6]), ge=float(p[7]), d=float(p[8])))
    return rows


def q(v, p):
    s = sorted(v)
    pos = p * (len(s) - 1)
    lo = int(pos)
    hi = min(lo + 1, len(s) - 1)
    return s[lo] * (1 - (pos - lo)) + s[hi] * (pos - lo)


def union_len(iv, lo=None, hi=None):
    ev = []
    for a, b in iv:
        if lo is not None:
            a, b = max(a, lo), min(b, hi)
        if b > a:
            ev += [(a, 1), (b, -1)]
    ev.sort(key=lambda e: (e[0], -e[1]))
    dep = 0
    last = 0
    tot = 0.0
    for t, d in ev:
        if dep > 0:
            tot += t - last
        dep += d
        last = t
    return tot


# ---- 1. Section 4
rows = load(T / "serve1_6warm.15048.tsv.gz")
wp = sorted([r for r in rows if r["tag"] == "wprod" and r["detail"].startswith("t=128")], key=lambda r: r["b"])
wp = wp[len(wp) - 224 * 7:]
starts = [min(r["b"] for r in wp[224 * i:224 * i + 3]) for i in range(7)]
nonw = [r for r in rows if r["tag"] == "batch"]
print("Section 4 (serve1): request windows = [first QKV wprod begin of request i, same of request i+1)")
slot = {}
for i in range(1, 7):  # warm requests
    lo = starts[i]
    hi = starts[i + 1] if i < 6 else 1e18
    acc = {}
    for r in nonw:
        if lo <= r["b"] < hi and r["gs"] > 0:
            m = re.match(r"slot (\d+) \((.*?)\) at ", r["detail"])
            if m:
                key = (int(m.group(1)), m.group(2))
                acc[key] = acc.get(key, 0.0) + max(0.0, r["ge"] - r["gs"])
    for k, v in acc.items():
        slot.setdefault(k, []).append(v / 32 * 1000)
tot = 0
for k in sorted(slot, key=lambda k: -q(slot[k], .5)):
    v = slot[k]
    tot += q(v, .5)
    print(f"  slot {k[0]:2d} {k[1][:50]:50s} n={len(v)} median {q(v,.5):8.3f} ms/blk iqr {q(v,.75)-q(v,.25):.3f} mean {st.mean(v):.3f}")
print("  sum of medians", round(tot, 3), "; slots 14..18:", round(sum(q(v, .5) for k, v in slot.items() if 14 <= k[0] <= 18), 3))
print("  Report: 44.535 30.324 18.333 10.288 6.975 6.910 5.614 4.066 2.435 2.029 1.796 1.247 0.077 0.017 ; 14..18 = 109.094 ; sum 134.646")

# ---- 2/3. shares of mean and overlap share
import importlib.util
spec = importlib.util.spec_from_file_location("rt", "/dev/null")  # not used; keep the script standalone
ARMS = {"serve1": ("serve1_6warm.15048.tsv.gz", 1), "serve4": ("serve4_lanes2_6warm.15818.tsv.gz", 4), "serve6": ("serve6_lanes3_6warm.16734.tsv.gz", 6)}
for arm, (gz, R) in ARMS.items():
    rows = load(T / gz)
    wp = sorted([r for r in rows if r["tag"] == "wprod" and r["detail"].startswith("t=128")], key=lambda r: r["b"])
    extra = len(wp) - 224 * (1 + 6 * R)
    wp = wp[extra:]
    nonw = [r for r in rows if r["tag"] != "wprod"]
    ivs = [(r["gs"], r["ge"]) for r in nonw if r["gs"] > 0 and r["ge"] >= r["gs"]]
    print(f"\n{arm}: share of each request's wprod-chain window in which a NON-wprod (prover) command buffer is executing; per position, median over passes")
    for pos in range(R):
        sh = []
        for p in range(6):
            i = 1 + p * R + pos
            ch = wp[224 * i:224 * (i + 1)]
            lo = min(r["b"] for r in ch)
            hi = max(r["d"] for r in ch)
            sh.append(union_len(ivs, lo, hi) / (hi - lo))
        print(f"   req {pos}: busy share of window {q(sh,.5):.3f}  (min {min(sh):.3f} max {max(sh):.3f})")
