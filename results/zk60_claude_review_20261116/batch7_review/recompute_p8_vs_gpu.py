#!/usr/bin/env python3
"""Batch 7 review: does the length of each P8 gap (host-only, no witness command buffer in flight) track how busy the prover's
GPU work is during that same gap?  If P8's slowdown came from GPU memory-bandwidth contention, longer gaps should coincide
with a busier prover GPU.  Standard library only, read-only.  Run: python3 -I recompute_p8_vs_gpu.py"""
import bisect, gzip, statistics as st
from pathlib import Path
T = Path("/Users/victorrielly/zk60-artifacts/batch7_traces_20261117")
def load(p):
    rows = []
    with gzip.open(p, "rt") as f:
        for l in f:
            x = l.rstrip("\n").split("\t")
            if x[0] == "tag" or len(x) != 9: continue
            rows.append((x[0], x[1], float(x[4]), float(x[5]), float(x[6]), float(x[7]), float(x[8])))
    return rows
def merged(iv):
    out = []
    for a, b in sorted(iv):
        if out and a <= out[-1][1]: out[-1][1] = max(out[-1][1], b)
        else: out.append([a, b])
    return out
def cover(m, st_, a, b):
    i = max(0, bisect.bisect_right(st_, a) - 1); tot = 0.0
    while i < len(m) and m[i][0] < b:
        lo, hi = max(a, m[i][0]), min(b, m[i][1])
        if hi > lo: tot += hi - lo
        i += 1
    return tot
def pearson(x, y):
    mx, my = st.mean(x), st.mean(y)
    sx = sum((a - mx) ** 2 for a in x) ** .5; sy = sum((b - my) ** 2 for b in y) ** .5
    return sum((a - mx) * (b - my) for a, b in zip(x, y)) / (sx * sy)
for arm, gz, R in (("serve4", "serve4_lanes2_6warm.15818.tsv.gz", 4), ("serve6", "serve6_lanes3_6warm.16734.tsv.gz", 6)):
    rows = load(T / gz)
    wp = sorted([r for r in rows if r[0] == "wprod" and r[1].startswith("t=128")], key=lambda r: r[2])
    wp = wp[len(wp) - 224 * (1 + 6 * R):]
    prov = merged([(r[4], r[5]) for r in rows if r[0] != "wprod" and r[4] > 0 and r[5] >= r[4]])
    pst = [m[0] for m in prov]
    xs, ys, bypos = [], [], {}
    for p in range(6):
        for pos in range(1, R):
            ch = wp[224 * (1 + p * R + pos):224 * (2 + p * R + pos)]
            blocks = [ch[7 * i:7 * i + 7] for i in range(32)]
            for i in range(1, 32):
                a = blocks[i - 1][6][6]; b = min(r[2] for r in blocks[i][:3])
                g = b - a
                xs.append(cover(prov, pst, a, b) / g); ys.append(g * 1000)
    lo = [y for x, y in zip(xs, ys) if x < 0.5]; hi = [y for x, y in zip(xs, ys) if x >= 0.5]
    print(f"{arm}: n gaps {len(xs)}; Pearson r(gap length, prover GPU busy share in the gap) = {pearson(xs,ys):.3f}")
    print(f"   gaps with prover GPU busy < 50% of the gap: n={len(lo)} median {st.median(lo):.1f} ms ; >= 50%: n={len(hi)} median {st.median(hi):.1f} ms")
    qs = sorted(zip(xs, ys))
    k = len(qs) // 4
    print("   by quartile of prover busy share: " + ", ".join(f"[{q[0][0]:.2f}..{q[-1][0]:.2f}] median {st.median([y for _, y in q]):.1f} ms" for q in (qs[:k], qs[k:2*k], qs[2*k:3*k], qs[3*k:])))
