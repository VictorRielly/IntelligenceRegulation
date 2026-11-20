#!/usr/bin/env python3
"""Claude co-coordinator, 2026-11-20: a per-lane reading of Astra's GPU trace of the app's stream.

Read-only recomputation, standard library. Input: Astra's attempt directory
results/zk60_astra_20261026/app_stream_timing_20261120/attempts/20261120T220225Z/ (prover.1484.tsv, TIMINGS.json).
Run: python3 -B app_trace_lanes.py [attempt_dir]

What it reports: how long the GPU has no command buffer executing, split by how many of the six lanes are inside
their 26 blocks at that moment; the block period of one lane; and how often two lanes start a block at the same
instant. A request's block phase is taken as [begin of its first commit A, begin of its 26th commit A plus one mean
block period]; commit A is the commit record with rows=2504.
"""
import bisect
import collections
import json
import statistics as st
import sys

D = sys.argv[1] if len(sys.argv) > 1 else (
    "/Users/victorrielly/IntelligenceRegulation/results/zk60_astra_20261026/app_stream_timing_20261120/"
    "attempts/20261120T220225Z/")
D = D.rstrip("/") + "/"
T = json.load(open(D + "TIMINGS.json"))
rows = []
for line in open(D + "prover.1484.tsv").read().splitlines()[1:]:
    r = line.split("\t")
    rows.append([r[0], r[1], r[2], r[3]] + [float(x) for x in r[4:9]])
t0 = min(r[4] for r in rows)
for r in rows:
    for i in range(4, 9):
        r[i] -= t0
proved = sorted(v + T["wall_to_mach_start"] - t0 for v in T["stamps"]["proved"].values())
cnt = collections.Counter(r[2] for r in rows if r[0] == "commit" and r[1].startswith("rows=2504 "))
LANES = sorted((k for k, v in cnt.items() if v >= 26), key=int)
print("lanes (threads with commit A records):", LANES, "| commit A per lane:", [cnt[k] for k in LANES])
blk = {}
for ln in LANES:
    ca = sorted(r[4] for r in rows if r[2] == ln and r[0] == "commit" and r[1].startswith("rows=2504 "))
    blk[ln] = [ca[i:i + 26] for i in range(0, len(ca), 26)]
phase = {ln: [(q[0], q[-1] + (q[-1] - q[0]) / 25.0) for q in blk[ln]] for ln in LANES}
groups = [proved[i:i + len(LANES)] for i in range(0, len(proved), len(LANES))]
print("proof completions, seconds from the first trace record, in groups of %d:" % len(LANES))
for g in groups:
    print("   " + " ".join("%.2f" % x for x in g))
print("group to group (first completion of each): " + " ".join(
    "%.2f" % (b[0] - a[0]) for a, b in zip(groups, groups[1:])))

ev = sorted([(r[6], 1) for r in rows] + [(r[7], -1) for r in rows])
pts = sorted(set([e[0] for e in ev] + [x for ln in LANES for p in phase[ln] for x in p]))
W0, W1 = min(p[0][0] for p in phase.values()), max(proved)
acc = collections.defaultdict(float)
k = ei = 0
for a, b in zip(pts, pts[1:]):
    while ei < len(ev) and ev[ei][0] <= a:
        k += ev[ei][1]
        ei += 1
    lo, hi = max(a, W0), min(b, W1)
    if hi > lo:
        mid = (lo + hi) / 2
        n = sum(1 for ln in LANES for (s, e) in phase[ln] if s <= mid < e)
        acc[(n, k > 0)] += hi - lo
tot = sum(acc.values())
B = sum(v for (n, busy), v in acc.items() if busy)
print("\nwindow: first commit A to last proof completion, %.2f s; GPU busy %.2f s (%.1f%%), idle %.2f s" % (
    tot, B, 100 * B / tot, tot - B))
print("GPU busy per proof in this window: %.3f s -> %.1f tok/s if the GPU were never idle (a ceiling)" % (
    B / len(proved), 128 * len(proved) / B))
print("lanes inside their blocks | time s | GPU busy s | busy share | idle s")
for n in range(len(LANES) + 1):
    b, i = acc.get((n, True), 0.0), acc.get((n, False), 0.0)
    if b + i > 0:
        print("  %d | %6.2f | %6.2f | %5.1f%% | %5.2f" % (n, b + i, b, 100 * b / (b + i), i))

per = [b - a for ln in LANES for q in blk[ln] for a, b in zip(q, q[1:])]
print("\nblock period of one lane (commit A to commit A): median %.3f s (p10 %.3f, p90 %.3f, n %d); "
      "six lanes: %.1f ms of wall per block" % (
          st.median(per), sorted(per)[len(per) // 10], sorted(per)[9 * len(per) // 10], len(per),
          1e3 * st.median(per) / len(LANES)))
allca = {ln: sorted(x for q in blk[ln] for x in q) for ln in LANES}
for tol in (0.010, 0.030):
    hit = n = 0
    for ln in LANES:
        for x in allca[ln]:
            for l2 in LANES:
                if l2 != ln:
                    arr = allca[l2]
                    i = bisect.bisect_left(arr, x)
                    d = min(abs(x - arr[j]) for j in (i - 1, i) if 0 <= j < len(arr))
                    n += 1
                    hit += d <= tol
    print("a lane's commit A begins within %.0f ms of another lane's commit A: %.1f%% of lane pairs "
          "(%.1f%% if the lanes' phases were unrelated)" % (tol * 1e3, 100 * hit / n, 100 * 2 * tol / st.median(per)))

# GPU demand of one lane inside its blocks: union of [committed, gpu_end] of its own buffers
dem = []
for ln in LANES:
    iv = sorted((r[5], r[7]) for r in rows if r[2] == ln)
    for (s, e) in phase[ln]:
        u, cur_s, cur_e = 0.0, None, None
        for a, b in iv:
            a, b = max(a, s), min(b, e)
            if b <= a:
                continue
            if cur_e is None or a > cur_e:
                if cur_e is not None:
                    u += cur_e - cur_s
                cur_s, cur_e = a, b
            else:
                cur_e = max(cur_e, b)
        if cur_e is not None:
            u += cur_e - cur_s
        dem.append(u / (e - s))
d = st.mean(dem)
print("\none lane, inside its blocks, has a buffer waiting or executing %.1f%% of the time (mean over %d requests)" % (
    100 * d, len(dem)))
full_b, full_i = acc.get((len(LANES), True), 0.0), acc.get((len(LANES), False), 0.0)
print("with all %d lanes inside their blocks the GPU is idle %.1f%% of the time; %d lanes with unrelated phases "
      "would leave it idle %.1f%%" % (len(LANES), 100 * full_i / (full_b + full_i), len(LANES),
                                     100 * (1 - d) ** len(LANES)))
