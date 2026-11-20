#!/usr/bin/env python3
"""GPU time of the sealing (witness) pass: union and sum of the spans of its 224 queue-99 buffers per request, by arm and position; and how much of it
falls inside a prover-busy instant.   python3 -I witness_gpu.py"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import *

for arm in ARMS:
    A = windows(load_arm(arm))
    R = A["R"]
    prov = ivs(all_prover(A))
    res = {}
    for rq in A["reqs"]:
        if rq["key"][0] == "cold":
            continue
        q_ = rq["key"][1]
        W = [(r["gs"], r["ge"]) for r in rq["wprod"] if valid(r)]
        uw = union_len(W)
        sw = sum(b - a for a, b in W)
        lo, hi = min(r["b"] for r in rq["wprod"]), max(r["d"] for r in rq["wprod"])
        inter = intersect_len(W, clip(prov, lo, hi))
        cls = "request 0 (nothing beside)" if q_ == 0 else "requests 1.." + str(R - 1) + " (prover beside)"
        if R == 1:
            cls = "solo"
        res.setdefault(cls, []).append((uw, sw, inter, hi - lo))
    for cls, v in res.items():
        print("%-8s %-28s n=%2d  witness GPU union %.3f s (IQR %.3f), sum of spans %.3f s, chain wall %.3f s, of the union inside a prover-busy instant: %.3f s (%.0f %%)" % (
            arm, cls, len(v), med([x[0] for x in v]), iqr([x[0] for x in v]), med([x[1] for x in v]), med([x[3] for x in v]), med([x[2] for x in v]), 100 * med([x[2] / x[0] for x in v])))
