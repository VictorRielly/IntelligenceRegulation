#!/usr/bin/env python3
"""Split every prove call into: serial start phase (S to the first A or H commit buffer starting), fork region, join/tail (after the last fork buffer
that is not a rows=37/38 buffer), and report wall, prover-busy and idle (no prover buffer executing) in each.   python3 -I phases_of_call.py"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import *
from labels import group_of

for arm in ARMS:
    A = windows(load_arm(arm))
    R = A["R"]
    prov = all_prover(A)
    out = {}
    for rq in A["reqs"]:
        if rq["key"][0] == "cold":
            continue
        q_ = rq["key"][1]
        rc = "solo" if R == 1 else ("last" if q_ == R - 1 else "beside")
        P = [r for r in prov if rq["S"] <= 0.5 * (r["gs"] + r["ge"]) <= rq["E"]]
        big = [r for r in P if group_of(r).startswith(("commit A", "commit H"))]
        fork = [r for r in P if not group_of(r).startswith(("small",))]
        t1 = min(r["gs"] for r in big)
        t2 = max(r["ge"] for r in fork)
        U = ivs(P)
        seg = {}
        for nm, lo, hi in (("start (S..first big commit)", rq["S"], t1), ("forks (first big commit..last fork buffer)", t1, t2), ("join/tail (..E)", t2, rq["E"])):
            seg[nm] = (hi - lo, union_len(U, lo, hi))
        out.setdefault(rc, []).append(seg)
    for rc, L in out.items():
        print("\n%s / %s (n=%d)  median wall | prover busy | idle (no prover buffer executing), s" % (arm, rc, len(L)))
        for nm in L[0]:
            w = med([x[nm][0] for x in L]); b = med([x[nm][1] for x in L]); i = med([x[nm][0] - x[nm][1] for x in L])
            print("   %-46s %6.3f | %6.3f | %6.3f" % (nm, w, b, i))
