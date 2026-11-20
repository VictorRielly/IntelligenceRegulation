"""Where commit A's slow mode sits: GPU execution time of the two commits per warm pass against the GPU idle gap
before each. Standard library only; reads the retained traces, runs nothing. Backs the README's addendum.

Usage: python3 -B commit_a_mode.py

Trace columns: tag, detail, thread, queue, begin, committed, gpu_start, gpu_end, done (seconds). A pass starts at
each commit whose row count equals the trace's first commit's; pass 1 is cold and dropped; wprod records are dropped
from a pass. In the batched arms a pass is: commit A, three diagnostic records, commit H, ... so position 0 is
commit A and position 4 is commit H. The gap is from the latest GPU end of any earlier record (wprod included) to
this record's GPU start.
"""
import glob
import gzip
import os
import statistics

DIRS = [
    "/Users/victorrielly/zk60-artifacts/w16r2_shield_block_20261120",
    "/Users/victorrielly/zk60-artifacts/slot18_14_traces_20261117",
]
# batched traces only (the unbatched arms B and C have a different record sequence per pass)
NAMES = ["w16r2_shield_a1", "w16r2_shield_a2", "w16r2_8b_ctl", "r13_shield_ctl",
         "w16r2_8b_armA", "r13_shield_armA", "knob_tail250", "knob_tg256"]
SLOW = 1.15


def load(f):
    rows = [l.split("\t") for l in gzip.open(f, "rt").read().splitlines()[1:]]
    out, prev_end = [], None
    for r in rows:
        b, c, gs, ge, dn = [float(x) for x in r[4:9]]
        gap = (gs - prev_end) * 1e3 if prev_end is not None else float("nan")
        out.append({"tag": r[0], "detail": r[1], "gpu": (ge - gs) * 1e3, "gap": gap,
                    "enc": (c - b) * 1e3, "wait": (gs - c) * 1e3, "tail": (dn - ge) * 1e3})
        prev_end = ge if prev_end is None else max(prev_end, ge)
    return out


def passes(recs):
    idx = [i for i, r in enumerate(recs) if r["tag"] == "commit"]
    a = recs[idx[0]]["detail"].split()[0]
    starts = [i for i in idx if recs[i]["detail"].split()[0] == a]
    out = []
    for k, s in enumerate(starts):
        e = starts[k + 1] if k + 1 < len(starts) else len(recs)
        out.append([r for r in recs[s:e] if r["tag"] != "wprod"])
    return out


def main():
    all_a, all_h, w_a = [], [], []
    for d in DIRS:
        for f in sorted(glob.glob(d + "/*.tsv.gz")):
            base = os.path.basename(f)
            if not any(n in base for n in NAMES):
                continue
            warm = passes(load(f))[1:]
            assert all(p[0]["tag"] == "commit" and p[4]["tag"] == "commit" for p in warm), base
            a = [p[0] for p in warm]
            h = [p[4] for p in warm]
            fa = min(r["gpu"] for r in a)
            fh = min(r["gpu"] for r in h)
            print("%-42s A gpu %s | gap %s | wait %s" % (
                base[:42], " ".join("%5.1f" % r["gpu"] for r in a), " ".join("%3.0f" % r["gap"] for r in a),
                " ".join("%4.2f" % r["wait"] for r in a)))
            print("%-42s H gpu %s | gap %s" % (
                "", " ".join("%5.1f" % r["gpu"] for r in h), " ".join("%3.0f" % r["gap"] for r in h)))
            rows_a = [(r["gpu"] / fa, r["gpu"], r["gpu"] - fa, r["gap"]) for r in a]
            all_a += rows_a
            all_h += [(r["gpu"] / fh, r["gap"]) for r in h]
            if "w16r2" in base:
                w_a += rows_a
    slow = [x for x in all_a if x[0] >= SLOW]
    print()
    print("commit A: %d of %d warm passes at least %d%% above the fastest pass of their trace (ratio %.2f to %.2f)" % (
        len(slow), len(all_a), round((SLOW - 1) * 100), min(x[0] for x in slow), max(x[0] for x in slow)))
    print("commit H: %d of %d; largest ratio %.2f; gaps %.0f to %.0f ms" % (
        sum(1 for r, _ in all_h if r >= SLOW), len(all_h), max(r for r, _ in all_h),
        min(g for _, g in all_h), max(g for _, g in all_h)))
    ws = [x for x in w_a if x[0] >= SLOW]
    wf = [x for x in w_a if x[0] < SLOW]
    print("W16R2 only (%d passes): slow %d, GPU time %.1f to %.1f ms; gaps of slow passes %.0f to %.0f ms (median "
          "%.0f), of fast passes %.0f to %.0f ms (median %.0f)" % (
              len(w_a), len(ws), min(x[1] for x in ws), max(x[1] for x in ws),
              min(x[3] for x in ws), max(x[3] for x in ws), statistics.median(x[3] for x in ws),
              min(x[3] for x in wf), max(x[3] for x in wf), statistics.median(x[3] for x in wf)))
    print("W16R2 only: mean excess of commit A over the fastest pass of its trace %.2f ms per block" % (
        statistics.mean(x[2] for x in w_a)))


main()
