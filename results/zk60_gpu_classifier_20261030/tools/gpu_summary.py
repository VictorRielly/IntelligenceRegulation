#!/usr/bin/env python3
"""GPU classifier lane: summarise a gpu_sampler.sh CSV (busy samples = util > 0 or memory > 0 beyond idle).
usage: gpu_summary.py CSV"""
import sys, collections
rows = []
for line in open(sys.argv[1]):
    p = [x.strip() for x in line.split(',')]
    if len(p) != 9 or not p[2].split()[0].isdigit():
        continue
    sm = int(p[2].split()[0]); mem = int(p[3].split()[0]); thr = p[4]; pw = p[5]; tc = p[6]; used = int(p[7].split()[0]); ut = int(p[8].split()[0])
    rows.append((p[1], sm, mem, thr, pw, tc, used, ut))
busy = [r for r in rows if r[7] > 0]
print(f"samples {len(rows)}, busy (util > 0) {len(busy)}")
if busy:
    print("pstate", dict(collections.Counter(r[0] for r in busy)))
    print("SM MHz min/median/max", min(r[1] for r in busy), sorted(r[1] for r in busy)[len(busy)//2], max(r[1] for r in busy))
    print("mem MHz", dict(collections.Counter(r[2] for r in busy)))
    print("throttle reasons", dict(collections.Counter(r[3] for r in busy)))
    print("util % median", sorted(r[7] for r in busy)[len(busy)//2], "mean", round(sum(r[7] for r in busy)/len(busy), 1))
    print("temp C max", max(int(float(r[5])) for r in busy if r[5].replace('.','',1).isdigit()) if any(r[5].replace('.','',1).isdigit() for r in busy) else '?')
print("memory.used MiB max", max((r[6] for r in rows), default=0))
