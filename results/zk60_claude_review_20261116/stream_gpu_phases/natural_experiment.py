#!/usr/bin/env python3
"""Does the prove-call time P follow the prover's GPU-busy union U or the idle (host-only) time H = P - U, across the 114 warm prove calls
of the three traces?  Also the maximum number of command buffers executing at once.   python3 -I natural_experiment.py"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import *


def corr(x, y):
    n = len(x)
    mx, my = sum(x) / n, sum(y) / n
    sxy = sum((a - mx) * (b - my) for a, b in zip(x, y))
    sxx = sum((a - mx) ** 2 for a in x)
    syy = sum((b - my) ** 2 for b in y)
    return sxy / (sxx * syy) ** 0.5, sxy / sxx


for arm in ARMS:
    A = windows(load_arm(arm))
    R = A["R"]
    prov = all_prover(A)
    wit = all_wit(A)
    # max depth
    for nm, rows in (("prover only", prov), ("prover + witness", prov + wit)):
        segs = depth_segments(ivs(rows), min(r["gs"] for r in rows), max(r["ge"] for r in rows))
        mx = max(d for a, b, d in segs)
        tt = {}
        for a, b, d in segs:
            tt[d] = tt.get(d, 0.0) + (b - a)
        print("%s: max number of buffers executing at once, %s: %d   (time at depth 4+: %.3f s of %.1f s busy)" % (arm, nm, mx, sum(v for d, v in tt.items() if d >= 4), sum(v for d, v in tt.items() if d >= 1)))
    pts = []
    for rq in A["reqs"]:
        if rq["key"][0] == "cold":
            continue
        P = [r for r in prov if rq["S"] <= 0.5 * (r["gs"] + r["ge"]) <= rq["E"]]
        U = union_len(ivs(P), rq["S"], rq["E"])
        Pc = rq["E"] - rq["S"]
        pts.append((Pc, U, Pc - U, rq["key"]))
    xs = [p[1] for p in pts]; ys = [p[0] for p in pts]; hs = [p[2] for p in pts]
    r1, s1 = corr(xs, ys)
    r2, s2 = corr(hs, ys)
    print("   n=%d prove calls: corr(P, union) %.2f slope %.2f ; corr(P, idle) %.2f slope %.2f ; sd(P) %.3f sd(union) %.3f sd(idle) %.3f" % (
        len(pts), r1, s1, r2, s2, (sum((y - sum(ys) / len(ys)) ** 2 for y in ys) / len(ys)) ** .5,
        (sum((x - sum(xs) / len(xs)) ** 2 for x in xs) / len(xs)) ** .5, (sum((h - sum(hs) / len(hs)) ** 2 for h in hs) / len(hs)) ** .5))
