#!/usr/bin/env python3
"""Batch 7 review: what is the 'queue wait' (commit -> GPUStartTime) of a witness command buffer made of?
Standard library only, read-only.  Run: python3 -I recompute_wait.py

For every wprod command buffer of the warm requests: wait = gpu_start - committed.  In the overlapped
requests, how much of each wait interval has a prover command buffer (any non-wprod buffer) executing on the GPU?
If the wait is mostly spent while prover work executes, it is waiting behind that work; the part not covered
is a latency that exists with no other work running (as in the solo requests).
"""
import bisect
import gzip
import statistics as st
from pathlib import Path

T = Path("/Users/victorrielly/zk60-artifacts/batch7_traces_20261117")
ARMS = {"serve1": ("serve1_6warm.15048.tsv.gz", 1), "serve4": ("serve4_lanes2_6warm.15818.tsv.gz", 4), "serve6": ("serve6_lanes3_6warm.16734.tsv.gz", 6)}


def load(path):
    rows = []
    with gzip.open(path, "rt") as f:
        for line in f:
            p = line.rstrip("\n").split("\t")
            if p[0] == "tag" or len(p) != 9:
                continue
            kv = dict(tok.split("=", 1) for tok in p[1].split() if "=" in tok)
            rows.append(dict(tag=p[0], detail=p[1], kv=kv, b=float(p[4]), c=float(p[5]), gs=float(p[6]), ge=float(p[7]), d=float(p[8])))
    return rows


def merged(iv):
    iv = sorted(iv)
    out = []
    for a, b in iv:
        if out and a <= out[-1][1]:
            out[-1][1] = max(out[-1][1], b)
        else:
            out.append([a, b])
    return out


def covered(m, starts, a, b):
    """length of [a,b] covered by merged intervals m"""
    i = max(0, bisect.bisect_right(starts, a) - 1)
    tot = 0.0
    while i < len(m) and m[i][0] < b:
        lo, hi = max(a, m[i][0]), min(b, m[i][1])
        if hi > lo:
            tot += hi - lo
        i += 1
    return tot


def med(v):
    return st.median(v)


for arm, (gz, R) in ARMS.items():
    rows = load(T / gz)
    wp = sorted([r for r in rows if r["tag"] == "wprod" and r["detail"].startswith("t=128")], key=lambda r: r["b"])
    wp = wp[len(wp) - 224 * (1 + 6 * R):]
    prov = merged([(r["gs"], r["ge"]) for r in rows if r["tag"] != "wprod" and r["gs"] > 0 and r["ge"] >= r["gs"]])
    starts = [m[0] for m in prov]
    print(f"\n== {arm}")
    for pos in range(R):
        waits, cov = [], []
        per_req_total_wait, per_req_cov = [], []
        for p in range(6):
            i = 1 + p * R + pos
            ch = wp[224 * i:224 * (i + 1)]
            tw = tc = 0.0
            for r in ch:
                w = max(0.0, r["gs"] - r["c"])
                c = covered(prov, starts, r["c"], r["gs"])
                waits.append(w)
                cov.append(c)
                tw += w
                tc += c
            per_req_total_wait.append(tw)
            per_req_cov.append(tc)
        print(f"   req {pos}: per-CB wait median {1000*med(waits):.2f} ms mean {1000*st.mean(waits):.2f} ms;  per-request sum of waits {med(per_req_total_wait):.3f} s, of which with prover executing {med(per_req_cov):.3f} s ({100*med(per_req_cov)/med(per_req_total_wait):.0f}%), without {med(per_req_total_wait)-med(per_req_cov):.3f} s")
