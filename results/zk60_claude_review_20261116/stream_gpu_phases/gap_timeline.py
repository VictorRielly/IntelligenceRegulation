#!/usr/bin/env python3
"""Where in the prove call (time since S) the union gaps (no prover buffer executing) of 5 ms or more fall, binned in 0.5 s slices, medians over calls.
python3 -I gap_timeline.py"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import *
from gaps import part_a

for arm in ARMS:
    A = windows(load_arm(arm))
    R = A["R"]
    prov = all_prover(A)
    bins = {}
    n = 0
    tot_by_bin = {}
    for rq in A["reqs"]:
        if rq["key"][0] == "cold":
            continue
        q_ = rq["key"][1]
        if R > 1 and q_ == R - 1:
            continue  # contended calls only for stream arms
        n += 1
        P = [r for r in prov if rq["S"] <= 0.5 * (r["gs"] + r["ge"]) <= rq["E"]]
        gaps = part_a(A, rq, P)
        win = rq["E"] - rq["S"]
        for a, b, pv, nx in gaps:
            # split gap over 0.5 s slices
            t = a
            while t < b:
                k = int((t - rq["S"]) / 0.5)
                e = min(b, rq["S"] + (k + 1) * 0.5)
                tot_by_bin.setdefault(k, []).append((n, e - t, b - a))
                t = e
    per = {}
    for k, L in tot_by_bin.items():
        byreq = {}
        for i, dt, gl in L:
            byreq[i] = byreq.get(i, 0.0) + dt
        per[k] = [byreq.get(i, 0.0) for i in range(1, n + 1)]
    print("\n%s: union-gap seconds per 0.5 s slice of the prove call (median over %d calls); idle share of the slice" % (arm, n))
    print("   slice (s since call start): " + " ".join("%5.1f" % (0.5 * k) for k in sorted(per)))
    print("   idle ms in slice          : " + " ".join("%5.0f" % (1000 * med(per[k])) for k in sorted(per)))
