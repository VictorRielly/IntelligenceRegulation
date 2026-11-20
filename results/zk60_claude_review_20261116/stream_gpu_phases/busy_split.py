#!/usr/bin/env python3
"""Items 1 and 3: GPU-busy union split by owner (witness = queue 99 'wprod', prover = every other buffer, all on queue 0),
and the prover concurrency (depth) distribution inside the prove call.   python3 -I busy_split.py   (prints tables; stdlib only)

Owners: [gs, ge] of each command buffer (Metal GPUStartTime / GPUEndTime).  Medians over the 6 warm passes (n stated).
"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import *


def owner_split(P, W, lo, hi):
    """seconds in [lo, hi]: prover only, witness only, both, neither"""
    up = union_len(P, lo, hi)
    uw = union_len(W, lo, hi)
    both = union_len(P + W, lo, hi)  # union of everything
    inter = up + uw - both
    return dict(win=hi - lo, p_only=up - inter, w_only=uw - inter, both=inter, neither=(hi - lo) - both, p_union=up, w_union=uw, any=both)


def fmt(v, d=3):
    return ("%." + str(d) + "f") % v


print("=" * 100)
print("ITEM 1a  GPU-busy union per steady request, split by owner (window and per-request normalisation as in the Batch 7 review)")
print("  serve1: window = [pass start, result] of the one request; serve4 / serve6: [result(0), result(R-1)] / (R-1) requests, per pass")
print("=" * 100)
ARMD = {}
for arm in ARMS:
    A = windows(load_arm(arm))
    ARMD[arm] = A
    R = A["R"]
    P = ivs(all_prover(A))
    W = ivs(all_wit(A))
    rows = []
    for p in range(NPASS):
        i = 1 + p * R
        r0, rl = A["reqs"][i], A["reqs"][i + R - 1]
        if R == 1:
            lo, hi, n = r0["t0"], r0["t0"] + r0["log"]["res"], 1
        else:
            lo, hi, n = r0["t0"] + r0["log"]["res"], rl["t0"] + rl["log"]["res"], R - 1
        d = owner_split(P, W, lo, hi)
        rows.append({k: v / n for k, v in d.items()} | {"n": n})
    print("\n%s (n = %d passes; per request; medians)" % (arm, NPASS))
    keys = [("win", "window per request"), ("any", "GPU busy union (any owner)"), ("p_only", "prover only"), ("w_only", "witness (queue 99) only"),
            ("both", "both overlapping"), ("neither", "neither (GPU idle)"), ("p_union", "prover union (alone + both)"), ("w_union", "witness union (alone + both)")]
    for k, nm in keys:
        v = [r[k] for r in rows]
        print("  %-34s %7.3f s  (IQR %.3f)  %5.1f %% of window" % (nm, med(v), iqr(v), 100 * med([r[k] / r["win"] for r in rows])))
    print("  busy union % of window per pass:", [round(100 * r["any"] / r["win"], 1) for r in rows])

print()
print("=" * 100)
print("ITEM 1b  inside the prove call window [S, E] (log prover start/end; trace anchor = first rows=38 commit minus preflight)")
print("=" * 100)
GROUP = {}
for arm in ARMS:
    A = ARMD[arm]
    R = A["R"]
    P = ivs(all_prover(A))
    W = ivs(all_wit(A))
    out = {}
    for i, rq in enumerate(A["reqs"]):
        if rq["key"][0] == "cold":
            continue
        q_ = rq["key"][1]
        d = owner_split(P, W, rq["S"], rq["E"])
        d["pc"] = rq["log"]["pc"]
        d["prove_only_busy_frac"] = d["p_union"] / d["win"]
        # position class: contended = a sealing pass of the next request runs beside it (q <= R-2); last = nothing beside it
        cls = "solo (serve1)" if R == 1 else ("last request, no sealing beside" if q_ == R - 1 else "beside next sealing pass")
        out.setdefault(cls, []).append(d)
    GROUP[arm] = out
    print("\n%s" % arm)
    print("  %-34s %3s %8s %10s %10s %10s %10s %10s %10s %10s" % ("class", "n", "P call", "prov busy", "prov busy%", "host-only", "host-only%", "wit-only", "both", "neither"))
    for cls, L in out.items():
        print("  %-34s %3d %8.3f %10.3f %9.1f%% %10.3f %9.1f%% %10.3f %10.3f %10.3f" % (
            cls, len(L), med([x["win"] for x in L]), med([x["p_union"] for x in L]), 100 * med([x["p_union"] / x["win"] for x in L]),
            med([x["win"] - x["p_union"] for x in L]), 100 * med([1 - x["p_union"] / x["win"] for x in L]),
            med([x["w_only"] for x in L]), med([x["both"] for x in L]), med([x["neither"] for x in L])))
    if R > 1:
        for q_ in range(R):
            L = [owner_split(P, W, rq["S"], rq["E"]) for rq in A["reqs"] if rq["key"][0] != "cold" and rq["key"][1] == q_]
            print("     request %d: n=%d P call %.3f  prov busy %.3f (%.1f %%)  host-only %.3f (%.1f %%)  witness-only %.3f  both %.3f" % (
                q_, len(L), med([x["win"] for x in L]), med([x["p_union"] for x in L]), 100 * med([x["p_union"] / x["win"] for x in L]),
                med([x["win"] - x["p_union"] for x in L]), 100 * med([1 - x["p_union"] / x["win"] for x in L]), med([x["w_only"] for x in L]), med([x["both"] for x in L])))

print()
print("=" * 100)
print("ITEM 3  prover concurrency inside the prove call: time share at depth d (prover buffers executing at one instant)")
print("=" * 100)
for arm in ARMS:
    A = ARMD[arm]
    R = A["R"]
    P = ivs(all_prover(A))
    W = ivs(all_wit(A))
    classes = {}
    for rq in A["reqs"]:
        if rq["key"][0] == "cold":
            continue
        q_ = rq["key"][1]
        cls = "solo" if R == 1 else ("last (no sealing)" if q_ == R - 1 else "beside sealing")
        segs = depth_segments(P, rq["S"], rq["E"])
        tot = {}
        for a, b, d in segs:
            tot[d] = tot.get(d, 0.0) + (b - a)
        win = rq["E"] - rq["S"]
        busy = win - tot.get(0, 0.0)
        mean_busy = sum(d * t for d, t in tot.items()) / busy
        # witness depth while prover busy (queue 99 overlap)
        classes.setdefault(cls, []).append((tot, win, mean_busy, sum(d * t for d, t in tot.items()) / win))
    for cls, L in classes.items():
        print("\n%s / %s (n = %d prove calls; medians of per-call time share)" % (arm, cls, len(L)))
        maxd = 9
        line = "   depth  :" + "".join(" %6s" % (str(d) if d < maxd else "%d+" % maxd) for d in range(maxd + 1))
        print(line)
        shares = []
        for d in range(maxd + 1):
            v = []
            for tot, win, mb, mw in L:
                s = sum(t for dd, t in tot.items() if (dd == d if d < maxd else dd >= maxd))
                v.append(s / win)
            shares.append(med(v))
        print("   share %%:" + "".join(" %6.1f" % (100 * s) for s in shares))
        print("   mean depth while busy %.2f (median), mean depth over the whole call %.2f; sum of spans / call = %.2f" % (
            med([x[2] for x in L]), med([x[3] for x in L]), med([x[3] for x in L])))
