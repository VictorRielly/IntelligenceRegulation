#!/usr/bin/env python3
"""Item 2 (and the GPU side of item 6): prover GPU time by label inside the prove call.   python3 -I labels.py

Per request (prove call window [S, E]) and per label:
  sum  = sum of execution spans (gs..ge) of that label's buffers           [adds up with overlap counted twice]
  own  = union of that label's spans                                        [time with at least one buffer of the label executing]
  eq   = equal-split share of the prover's busy union: every instant with depth d gives 1/d of its length to each executing buffer;
         the eq column sums exactly to the prover's busy union, so its shares add to 100 %
Medians over the requests of a class (n stated).  Classes: serve1 solo; stream 'beside the next sealing pass'; stream last request.
"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import *

GROUPS = [
    ("commit A (2504 rows)", "A commit"),
    ("commit H (2606 rows)", "H commit"),
]


def group_of(r):
    lab = label_of(r)
    if lab.startswith("commit small"):
        return "small commits (37/38 rows)"
    if lab.startswith("gather small"):
        return "small gathers (37/38 rows)"
    return lab


def eq_attribution(rows, lo, hi):
    """returns {group: equal-split seconds}; rows = prover rows of the window"""
    ev = []
    for i, r in enumerate(rows):
        a, b = max(r["gs"], lo), min(r["ge"], hi)
        if b > a:
            ev.append((a, 1, i))
            ev.append((b, -1, i))
    ev.sort(key=lambda e: (e[0], e[1]))
    live = set()
    last = None
    acc = {}
    for t, dl, i in ev:
        if last is not None and live and t > last:
            share = (t - last) / len(live)
            for j in live:
                g = group_of(rows[j])
                acc[g] = acc.get(g, 0.0) + share
        if dl > 0:
            live.add(i)
        else:
            live.discard(i)
        last = t
    return acc


def per_request(A, rq):
    P = [r for r in all_prover(A) if rq["S"] <= 0.5 * (r["gs"] + r["ge"]) <= rq["E"]]
    out = {}
    byg = {}
    for r in P:
        byg.setdefault(group_of(r), []).append(r)
    eq = eq_attribution(P, rq["S"], rq["E"])
    for g, L in byg.items():
        out[g] = dict(sum=sum(span(r) for r in L), own=union_len(ivs(L)), eq=eq.get(g, 0.0), n=len(L))
    busy = union_len(ivs(P))
    return out, busy, P


def collect(arm):
    A = windows(load_arm(arm))
    R = A["R"]
    classes = {}
    for rq in A["reqs"]:
        if rq["key"][0] == "cold":
            continue
        q_ = rq["key"][1]
        cls = "solo" if R == 1 else ("last" if q_ == R - 1 else "beside")
        out, busy, P = per_request(A, rq)
        classes.setdefault(cls, []).append((out, busy, rq))
    return A, classes


def slot_key(g):
    return g


if __name__ == "__main__":
    for arm in ARMS:
        A, classes = collect(arm)
        for cls, L in classes.items():
            n = len(L)
            labs = sorted({g for o, b, rq in L for g in o}, key=lambda g: -med([o.get(g, {}).get("eq", 0.0) for o, b, rq in L]))
            busy_med = med([b for o, b, rq in L])
            print("\n%s / %s: n = %d prove calls; prover GPU-busy union in the call (median) %.3f s; per request, ms (median), buffers per request" % (arm, cls, n, busy_med))
            print("  %-46s %8s %8s %8s %7s %6s" % ("label", "sum ms", "own ms", "eq ms", "eq %", "n/req"))
            tot_eq = 0
            for g in labs:
                s = med([o.get(g, {}).get("sum", 0.0) for o, b, rq in L]) * 1000
                ow = med([o.get(g, {}).get("own", 0.0) for o, b, rq in L]) * 1000
                eqv = med([o.get(g, {}).get("eq", 0.0) for o, b, rq in L]) * 1000
                share = 100 * med([o.get(g, {}).get("eq", 0.0) / b for o, b, rq in L])
                nb = med([o.get(g, {}).get("n", 0) for o, b, rq in L])
                tot_eq += eqv
                print("  %-46s %8.1f %8.1f %8.1f %6.1f%% %6.0f" % (g, s, ow, eqv, share, nb))
            print("  %-46s %8.1f %8s %8.1f" % ("TOTAL (sum of medians; eq sums to busy union)", sum(med([o.get(g, {}).get("sum", 0.0) for o, b, rq in L]) for g in labs) * 1000, "", tot_eq))
            # group roll-ups
            def roll(pred):
                return (med([sum(v["sum"] for g, v in o.items() if pred(g)) for o, b, rq in L]) * 1000,
                        med([sum(v["eq"] for g, v in o.items() if pred(g)) for o, b, rq in L]) * 1000,
                        100 * med([sum(v["eq"] for g, v in o.items() if pred(g)) / b for o, b, rq in L]))
            print("  roll-ups (sum ms | eq ms | eq share of union):")
            for nm, pred in [("A commit", lambda g: g.startswith("commit A")), ("H commit", lambda g: g.startswith("commit H")),
                             ("small commits", lambda g: g.startswith("small commits")), ("gathers A+H (openings, GPU part)", lambda g: g.startswith("gather")),
                             ("small gathers", lambda g: g.startswith("small gathers")),
                             ("sumcheck slots 0-4, 13 (norm, row sums, limb, masks, down)", lambda g: g.startswith("slot") and int(g.split()[1]) in (0, 1, 3, 4, 13)),
                             ("slots 14-18 (domain zero-checks D Q Kv S F)", lambda g: g.startswith("slot") and 14 <= int(g.split()[1]) <= 18),
                             ("slot 19 (TAB table helper)", lambda g: g.startswith("slot 19")),
                             ("slots 20-22 (ZS, IO-in, IO-out)", lambda g: g.startswith("slot") and int(g.split()[1]) >= 20),
                             ("all sumcheck slots", lambda g: g.startswith("slot"))]:
                s, e, sh = roll(pred)
                print("     %-58s %8.1f | %8.1f | %5.1f%%" % (nm, s, e, sh))
