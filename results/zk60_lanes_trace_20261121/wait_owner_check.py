#!/usr/bin/env python3
"""Whose buffer is a waiting prover buffer waiting for? (co-coordinator's check beside research tick 44)

    python3 -I -B wait_owner_check.py <trace.tsv.xz> [...]

Standard library only; reads retained device traces, runs nothing. A trace row is: tag, detail, thread, queue and five
times: host begin, committed (handed to the device), device start, device end, host done. A prover buffer is a row on a
queue other than 99 (99 holds the sealing buffers). Its wait is device start minus committed. Whole trace, no timed
window.

For each prover buffer the script asks two things.
 1. At the moment it was committed, was the previous buffer of the SAME queue still unfinished (its device end later
    than this buffer's commit)? Then the buffer is "behind its own queue": a queue runs its buffers in order, so this
    part of the wait is the lane waiting for itself. The wait is split at the previous buffer's end: the part up to
    that end is "own queue", the rest is "after own queue".
 2. Which end fell in the 0.5 ms before its device start: the same queue's previous buffer, a prover buffer of another
    queue, a sealing buffer, or none. The last column counts a device START on another queue in the same 0.5 ms.
"""
import bisect, lzma, os, sys

W = 0.0005


def load(f):
    rows = []
    for i, line in enumerate(lzma.open(f, 'rt')):
        p = line.rstrip('\n').split('\t')
        if i == 0 or len(p) != 9:
            continue
        rows.append((int(p[3]), float(p[5]), float(p[6]), float(p[7])))  # queue, committed, start, end
    return rows


def cnt(arr, lo, hi):
    return bisect.bisect_right(arr, hi) - bisect.bisect_right(arr, lo)


CLASSES = (('wait up to 0.5 ms', 0.0, W), ('0.5 to 5 ms', W, 0.005), ('over 5 ms', 0.005, 1e9))

for f in sys.argv[1:]:
    rows = load(f)
    byq = {}
    for r in rows:
        byq.setdefault(r[0], []).append(r)
    for v in byq.values():
        v.sort(key=lambda r: r[2])
    pq = sorted(q for q in byq if q != 99)
    ends_q = {q: sorted(r[3] for r in byq[q]) for q in byq}
    ends_p = sorted(r[3] for q in pq for r in byq[q])
    ends_s = ends_q.get(99, [])
    starts_q = {q: sorted(r[2] for r in byq[q]) for q in byq}
    starts_all = sorted(r[2] for r in rows)
    recs = []  # wait, own part, behind own queue, own end near start, other prover end near, sealing end near
    for q in pq:
        prev_end = None
        for (_, com, gs, ge) in byq[q]:
            wait = max(0.0, gs - com)
            behind = prev_end is not None and prev_end > com
            own = min(wait, max(0.0, prev_end - com)) if behind else 0.0
            o = prev_end is not None and gs - W < prev_end <= gs
            x = cnt(ends_p, gs - W, gs) - cnt(ends_q[q], gs - W, gs) > 0
            s = cnt(ends_s, gs - W, gs) > 0
            st = cnt(starts_all, gs - W, gs) - cnt(starts_q[q], gs - W, gs) > 0
            recs.append((wait, own, behind, o, x, s, st))
            prev_end = ge if prev_end is None else max(prev_end, ge)
    n = len(recs)
    tw = sum(r[0] for r in recs)
    to = sum(r[1] for r in recs)
    print('%s: %d prover queues, %d prover buffers, total wait %.1f s; own-queue part %.1f s (%.0f%%), after own queue %.1f s (%.0f%%)' % (
        os.path.basename(f), len(pq), n, tw, to, 100 * to / tw, tw - to, 100 * (tw - to) / tw))
    print('  %-18s %6s %6s %9s %8s %9s | start within 0.5 ms after an end of: %6s %9s %8s %6s' % (
        '', 'n', 'share', 'wait sum', 'behind', 'own part', 'own q', 'other P', 'sealing', 'none') + ' | a start of another queue in the 0.5 ms before')
    for name, lo, hi in CLASSES:
        sel = [r for r in recs if lo < r[0] <= hi] if lo > 0 else [r for r in recs if r[0] <= hi]
        if not sel:
            continue
        m = len(sel)
        ws = sum(r[0] for r in sel)
        os_ = sum(r[1] for r in sel)
        none = sum(1 for r in sel if not (r[3] or r[4] or r[5]))
        print('  %-18s %6d %5.1f%% %8.1fs %7.1f%% %8.0f%% | %37.1f%% %8.1f%% %7.1f%% %5.1f%% | %5.1f%%' % (
            name, m, 100.0 * m / n, ws, 100.0 * sum(1 for r in sel if r[2]) / m, 100 * os_ / ws if ws else 0.0,
            100.0 * sum(1 for r in sel if r[3]) / m, 100.0 * sum(1 for r in sel if r[4]) / m,
            100.0 * sum(1 for r in sel if r[5]) / m, 100.0 * none / m, 100.0 * sum(1 for r in sel if r[6]) / m))
