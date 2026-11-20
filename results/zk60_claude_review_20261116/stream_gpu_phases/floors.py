#!/usr/bin/env python3
"""Item 5 (two floors) and item 6 (candidate A in GPU terms).   python3 -I floors.py   (stdlib only)

Everything labelled MODEL is arithmetic on the measured numbers printed above it, not a measurement.
"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import *
import labels as L
import saturation as SAT

ONE_BLOCK_GPU_MS = 93.482       # Batch 6, BATCH6_HEAD_PROFILE_METRICS.json, prove_core_gpu_busy_from_cb_timestamps_ms median, n = 7
S_STEADY = 3.3535               # Batch 7 log: overlapped sealing pass, serve4 requests 1..3, median (review recomputed 3.353)
W_WRITE = 0.22                  # receipt write, Batch 7 logs
TARGET = 2.56

print("=" * 100)
print("Prove-call times by context (from the logs; medians; n)")
print("=" * 100)
ctx = {}
for arm in ARMS:
    A = windows(load_arm(arm))
    R = A["R"]
    for rq in A["reqs"]:
        if rq["key"][0] == "cold":
            continue
        q_ = rq["key"][1]
        c = "serve1 solo" if R == 1 else ("%s requests 0..%d (sealing beside)" % (arm, R - 2) if q_ <= R - 2 else "%s last request (nothing beside)" % arm)
        ctx.setdefault(c, []).append(rq["log"]["pc"])
        if R > 1 and q_ >= 1:
            ctx.setdefault("%s requests 1..%d (Batch 7 steady convention)" % (arm, R - 1), []).append(rq["log"]["pc"])
for c, v in ctx.items():
    print("  %-52s n=%2d  P median %.3f  IQR %.3f  min %.3f max %.3f" % (c, len(v), med(v), iqr(v), min(v), max(v)))

# ---- solo spans per label (pooled over the three traces, md < 1.1)
allpts = []
for arm in ARMS:
    A, pts = SAT.collect(arm)
    allpts += pts
solo = {}
fallback = {}
cnt_per_call = {}
for g in {p[0] for p in allpts}:
    sp = [p[3] for p in allpts if p[0] == g and p[1] < 1.1]
    if len(sp) >= 10:
        solo[g] = med(sp)
    else:
        sp2 = [p[3] for p in allpts if p[0] == g and p[1] < 1.75]
        if len(sp2) >= 10:
            solo[g] = med(sp2)
            fallback[g] = "md<1.75 median, n=%d (fewer than 10 solo samples)" % len(sp2)
        else:
            solo[g] = med([p[3] for p in allpts if p[0] == g])
            fallback[g] = "all samples median (no low-concurrency samples)"

print()
print("=" * 100)
print("ITEM 5  floors for the prove call")
print("=" * 100)
for arm in ARMS:
    A, classes = L.collect(arm)
    for cls, Lc in classes.items():
        U = med([b for o, b, rq in Lc])
        P = med([rq["log"]["pc"] for o, b, rq in Lc])
        # sum of solo spans: per call, sum over labels of (buffers in the call x pooled solo span)
        ser = []
        for o, b, rq in Lc:
            ser.append(sum(v["n"] * solo.get(g, 0.0) for g, v in o.items()))
        sumspan = med([sum(v["sum"] for v in o.values()) for o, b, rq in Lc])
        print("  %-8s %-7s n=%2d | P today %.3f | (i) prover busy union %.3f | (ii) sum of solo spans %.3f | sum of actual spans %.3f (x%.2f of union, x%.2f of solo sum) | idle %.3f" % (
            arm, cls, len(Lc), P, U, med(ser), sumspan, sumspan / U, sumspan / med(ser), P - U))
print("  one-block log: 32 blocks x %.3f ms = %.3f s  (the same sum of solo spans, from one block run alone, n = 7)" % (ONE_BLOCK_GPU_MS, 32 * ONE_BLOCK_GPU_MS / 1000))
print("  solo spans used (pooled md < 1.1, ms):")
for g in sorted(solo, key=lambda g: -solo[g]):
    print("     %-50s %7.2f ms %s" % (g, 1000 * solo[g], fallback.get(g, "")))
print("  target %.2f s (50 tok/s on 128 tokens); today's P 3.70 s (task) / measured medians above" % TARGET)

# ---- candidate A
print()
print("=" * 100)
print("ITEM 6  candidate A in GPU terms (measured spans for H commit and H open; model for the slot share)")
print("=" * 100)
# helper share of slots 14..18 by table count (Batch 6 review section 1.4, 'method E'): helper columns / table inputs
FR = {14: 10 / 37, 15: 3 / 15, 16: 3 / 15, 17: 4 / 19, 18: 4 / 19}
LOW = 8.0 / 16.5     # Batch 6 review: low end 8 ms against the table-count value 16.5 ms
for arm in ("serve1", "serve4", "serve6"):
    A, classes = L.collect(arm)
    for cls, Lc in classes.items():
        if cls == "last":
            continue
        n = len(Lc)
        U = med([b for o, b, rq in Lc])
        def eq(pred):
            return med([sum(v["eq"] for g, v in o.items() if pred(g)) for o, b, rq in Lc])
        def sm(pred):
            return med([sum(v["sum"] for g, v in o.items() if pred(g)) for o, b, rq in Lc])
        hc, ho = eq(lambda g: g.startswith("commit H")), eq(lambda g: g.startswith("gather H"))
        hcs, hos = sm(lambda g: g.startswith("commit H")), sm(lambda g: g.startswith("gather H"))
        slot_eq = {s: eq(lambda g, s=s: g.startswith("slot %02d" % s)) for s in FR}
        tab = eq(lambda g: g.startswith("slot 19"))
        helper_hi = sum(slot_eq[s] * FR[s] for s in FR)
        helper_lo = helper_hi * LOW
        P_today = 3.70
        print("\n  %s / %s, n = %d calls; prover busy union U = %.3f s" % (arm, cls, n, U))
        print("     MEASURED  H commit: eq-share %.0f ms (%.1f %% of U), sum of spans %.0f ms | H open (GPU gather): %.1f ms (%.2f %% of U), sum %.1f ms" % (1000 * hc, 100 * hc / U, 1000 * hcs, 1000 * ho, 100 * ho / U, 1000 * hos))
        print("     MODEL     helper share of slots 14-18 (table-count fractions D 27%%, Q 20%%, Kv 20%%, S 21%%, F 21%%): high %.0f ms, low end %.0f ms; slot 19 TAB 0..%.0f ms" % (1000 * helper_hi, 1000 * helper_lo, 1000 * tab))
        variants = [("A1: H commit + H open only (measured)", hc + ho),
                    ("A2: A1 + helper share slots 14-18, low end", hc + ho + helper_lo),
                    ("A3: A1 + helper share slots 14-18, table-count value", hc + ho + helper_hi),
                    ("A4: A3 + whole TAB slot 19", hc + ho + helper_hi + tab)]
        print("     %-50s %9s %7s | MODEL (P today %.2f s, S %.2f, W %.2f)" % ("variant", "dU ms", "% of U", P_today, S_STEADY, W_WRITE))
        cad0 = max(P_today, (S_STEADY + W_WRITE + P_today) / 2)
        cad3_0 = max(P_today, (S_STEADY + W_WRITE + P_today) / 3)
        for nm, d in variants:
            Pn = P_today - d
            cad2 = max(Pn, (S_STEADY + W_WRITE + Pn) / 2)
            cad3 = max(Pn, (S_STEADY + W_WRITE + Pn) / 3)
            print("     %-50s %9.0f %6.1f%% | P' %.3f  x%.3f | cadence %.3f (x%.3f; today %.3f) | %.3f (x%.3f)" % (
                nm, 1000 * d, 100 * d / U, Pn, P_today / Pn, cad2, cad0 / cad2, cad0, cad3, cad3_0 / cad3))
        # proportional variant (P follows U: upper reading)
        d = hc + ho + helper_hi
        print("     (upper reading, MODEL: P falls in proportion to U, A3: P' = %.3f, x%.3f; not used above because the host-only time need not shrink)" % (P_today * (1 - d / U), 1 / (1 - d / U)))
print()
print("  Batch 6 review, wall-time conversion for the stream cadence (BATCH6_REVIEW.md section 5): x1.09 (sealing unchanged) to x1.19 (sealing follows) for the 19.3 % list; x1.13 to x1.27 with the helper slots.")

print()
print("=" * 100)
print("MODEL  how much prover GPU-busy union must go for P = %.2f s, as a function of the host-only idle time that is left" % TARGET)
print("       dU = U + idle_left - %.2f  (P = U' + idle_left; the idle time is assumed independent of the GPU work)" % TARGET)
print("=" * 100)
for arm, U in (("serve1 solo (no sealing beside), U 2.508", 2.508), ("serve4 beside, U 2.688", 2.688), ("last request in stream (no sealing beside), U 2.501", 2.501)):
    cells = ["idle_left %.1f s: dU %4.0f ms (%4.1f %% of U)" % (i, 1000 * (U + i - TARGET), 100 * (U + i - TARGET) / U) for i in (0.0, 0.2, 0.4, 0.6, 0.8, 1.1)]
    print("  %-52s " % arm + " | ".join(cells))
