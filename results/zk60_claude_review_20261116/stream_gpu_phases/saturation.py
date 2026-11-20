#!/usr/bin/env python3
"""Items 4 and 5: does a buffer's execution span stretch when other buffers overlap it, and the two floors for the prove call.
python3 -I saturation.py     (stdlib only)

For every prover buffer inside a prove call: md = time-averaged number of command buffers executing during its own [gs, ge]
(itself included; prover and witness buffers of the whole trace counted).  md = 1 means it ran alone on the GPU.
Per label and md class: median span.  If spans grow in proportion to md, the GPU is saturated (overlap buys nothing);
if they stay flat, it has headroom.  Also: slope of span against md by least squares through the (md, span) points of a label.
"""
import sys
import bisect
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import *
from labels import group_of


class Depth:
    def __init__(self, intervals):
        ev = []
        for a, b in intervals:
            if b > a:
                ev.append((a, 1))
                ev.append((b, -1))
        ev.sort()
        self.t, self.d, self.C = [], [], []
        cur = 0
        cum = 0.0
        last = None
        for tm, dl in ev:
            if last is not None:
                cum += cur * (tm - last)
            cur += dl
            self.t.append(tm)
            self.d.append(cur)
            self.C.append(cum)
            last = tm

    def F(self, x):
        i = bisect.bisect_right(self.t, x) - 1
        if i < 0:
            return 0.0
        return self.C[i] + self.d[i] * (x - self.t[i])

    def mean(self, a, b):
        return (self.F(b) - self.F(a)) / (b - a) if b > a else float("nan")


CLASSES = [("1.0-1.1 (alone)", 0, 1.1), ("1.1-1.75", 1.1, 1.75), ("1.75-2.25 (~2)", 1.75, 2.25), ("2.25-2.75", 2.25, 2.75), (">2.75 (~3)", 2.75, 99)]


def cls_of(md):
    for nm, lo, hi in CLASSES:
        if lo <= md < hi:
            return nm
    return CLASSES[-1][0]


def lsq(xs, ys):
    n = len(xs)
    mx, my = sum(xs) / n, sum(ys) / n
    sxx = sum((x - mx) ** 2 for x in xs)
    if sxx < 1e-12:
        return float("nan"), float("nan")
    b = sum((x - mx) * (y - my) for x, y in zip(xs, ys)) / sxx
    return my - b * mx, b


def collect(arm):
    A = windows(load_arm(arm))
    allr = all_prover(A) + all_wit(A)
    D = Depth(ivs(allr))
    DP = Depth(ivs(all_prover(A)))
    pts = []  # (label group, md all, md prover, span, request class)
    R = A["R"]
    for rq in A["reqs"]:
        if rq["key"][0] == "cold":
            continue
        q_ = rq["key"][1]
        rc = "solo" if R == 1 else ("last" if q_ == R - 1 else "beside")
        for r in all_prover(A):
            pass
        break
    prov = all_prover(A)
    # assign rows to requests by window midpoint
    wins = [(rq["S"], rq["E"], rq) for rq in A["reqs"] if rq["key"][0] != "cold"]
    starts = [w[0] for w in wins]
    for r in prov:
        mid = 0.5 * (r["gs"] + r["ge"])
        i = bisect.bisect_right(starts, mid) - 1
        if i < 0 or mid > wins[i][1]:
            continue
        rq = wins[i][2]
        q_ = rq["key"][1]
        rc = "solo" if R == 1 else ("last" if q_ == R - 1 else "beside")
        sp = span(r)
        if sp <= 0:
            continue
        pts.append((group_of(r), D.mean(r["gs"], r["ge"]), DP.mean(r["gs"], r["ge"]), sp, rc))
    return A, pts


if __name__ == "__main__":
    allpts = {}
    for arm in ARMS:
        A, pts = collect(arm)
        allpts[arm] = pts
    labels = ["commit A (2504 rows)", "commit H (2606 rows)", "slot 14 03 D zero-check (hosts 12, 13D)", "slot 15 04 Q zero-check (hosts 09Q, 11)",
              "slot 16 05 KV zero-check (hosts 09K, 09V)", "slot 17 06 softmax zero-check (hosts 07, 10)", "slot 18 14 F zero-check (hosts 13G, 13U)",
              "slot 19 TAB table helper zero-check", "slot 00 01 SS row sums norm_a (private)", "slot 01 01m SS row sums norm_m (private)",
              "slot 04 07 masked row sums + selector (private)", "slot 03 08 limb zero-check", "slot 21 IO-in endpoint equality", "slot 22 IO-out endpoint equality"]
    present = {g for pts in allpts.values() for g, *_ in pts}
    labs = [g for g in labels if any(g.startswith(l[:14]) for l in present)]
    # normalise label names by prefix
    def canon(g):
        for l in labels:
            if g.startswith(l[:20]):
                return l
        return g
    print("=" * 110)
    print("ITEM 4  span of a buffer (ms, median, n) by mean concurrency md during its own span (all owners counted), per label and arm")
    print("=" * 110)
    for l in labels:
        print("\n%s" % l)
        print("   %-8s" % "arm" + "".join(" %-24s" % nm for nm, _, _ in CLASSES) + "   fit span = a + b*md   (a ms, b ms per unit md; n)")
        for arm, pts in allpts.items():
            sel = [(md, mp, sp) for g, md, mp, sp, rc in pts if canon(g) == l]
            cells = []
            for nm, lo, hi in CLASSES:
                v = [sp for md, mp, sp in sel if lo <= md < hi or (hi == 99 and md >= lo)]
                cells.append("%7.1f ms (n=%4d)     " % (1000 * med(v), len(v)) if v else "%-24s" % "-")
            a, b = lsq([md for md, mp, sp in sel], [1000 * sp for md, mp, sp in sel])
            print("   %-8s" % arm + "".join(" %-24s" % c.strip() for c in cells) + "   a %.1f b %.1f (n=%d, mean md %.2f)" % (a, b, len(sel), sum(md for md, _, _ in sel) / max(1, len(sel))))
    print()
    print("=" * 110)
    print("Stretch against the one-block log (Batch 6, 7 warm passes, one block alone: A commit GPU 13.376 ms, H commit GPU 14.001 ms, 23 slots 65.9 ms, opens 0.175 ms; total 93.482 ms)")
    print("=" * 110)
    for arm, pts in allpts.items():
        nblk = {"serve1": 6, "serve4": None, "serve6": None}[arm]
        # per-buffer mean span in prove-call windows, all requests (beside + last + solo)
        for sel_rc, nm in (("all", "all prove calls"),):
            ac = [sp for g, md, mp, sp, rc in pts if canon(g) == labels[0]]
            hc = [sp for g, md, mp, sp, rc in pts if canon(g) == labels[1]]
            slots = [sp for g, md, mp, sp, rc in pts if g.startswith("slot")]
            nreq = len(ac) / 32.0
            print("  %s (%d prove calls): A commit %.1f ms/buffer (%.2fx of 13.376); H commit %.1f ms/buffer (%.2fx of 14.001); slots %.1f ms per block (%.2fx of 65.9); all non-small buffers %.1f ms per block (%.2fx of 93.482)" % (
                arm, round(nreq), 1000 * sum(ac) / len(ac), sum(ac) / len(ac) / 0.013376, 1000 * sum(hc) / len(hc), sum(hc) / len(hc) / 0.014001,
                1000 * sum(slots) / (32 * nreq), sum(slots) / (32 * nreq) / 0.0659,
                1000 * (sum(ac) + sum(hc) + sum(slots)) / (32 * nreq), (sum(ac) + sum(hc) + sum(slots)) / (32 * nreq) / 0.093482))

