"""Tick 45 (queue item 73): what ends the long waits that do not end at a buffer end, and a convoy test.  Standard library only, reads retained traces.
Usage:  python3 -I -B this.py <traces dir of results/zk60_lanes_trace_20261121/raw/traces> [coin|convoy]
Legs 2 (six lanes, file tr_main_leg2.*) and 5 (eight lanes, tr_main_leg5.*).  Row: tag, detail, thread, queue, begin, committed, gpu_start, gpu_end, done.
Prover buffer = queue != 99; sealing buffers = queue 99.  Central window: starts (or commits) between 15% and 85% of the trace's time span (cuts ramp-up and drain);
events are taken from the whole trace.

PRE-REGISTERED LINES (written before the first count; the coordinator's item 73 asked for them)
 PART A, kinds of coincidence for prover buffers with committed-to-start wait q > 5 ms.  Kinds, tested in this priority on (s - 0.5 ms, s]:
   1 end of a prover buffer of another queue; 2 end of a sealing buffer; 3 commit (committed stamp) of a buffer of another queue; 4 host DONE stamp of a
   buffer of another queue; 5 (only if none of those) a device start of another queue within +-0.5 ms of s; 6 nothing.  Control: the same classification at
   s - d and s + d, d in {1, 1.5, 2, 2.5, 3} ms, same group.  Kind k "is real" if measured share >= 1.5 x the control share AND >= 3 points more.
   Pass of part A: a table for both legs; "explains the no-end majority" only if kinds 3 to 5 together leave 'nothing' at most 50% of the group's
   no-end starts at both legs and at least one of kinds 3 to 5 is real at both legs.
 PART B, the convoy.  In flight = [committed, gpu_end] of any buffer on any queue (sealing included).  A gap = a maximal stretch of at least 1 ms with nothing in
   flight, inside the central window.  Null: each prover queue (and each sealing thread) shifted rigidly by its own random offset around the trace (20 draws), which
   keeps each lane's own structure and breaks cross-lane synchrony.
   B1 (a gap begins after a cluster of ends): mean number of distinct queues (queue 99 counted once) with an end in the 1 ms before a gap's start >= 1.5 x the
      null's pass; < 1.2 x fail.
   B2 (a gap lasts about one lane host gap): the median gap length lies between the 25th and 75th percentile of the per-queue host gaps (a prover queue's next
      begin minus the previous done) pass; outside fail.
   B3 (the buffers committed at its end are the long waiters): among prover buffers committed in [gap end, gap end + 5 ms], the share that waits > 5 ms is
      >= 2 x the share among all prover buffers AND >= 2 x the null's, AND those buffers hold >= 40% of all long waiters: pass; < 1.3 x the base share or
      < 20% of the long waiters: fail.
   Verdict: convoy supported if B1, B2 and B3 pass at both legs; rejected if B3 fails at either leg; otherwise not decided.
"""
import bisect
import collections
import lzma
import os
import random
import statistics
import sys

D = sys.argv[1].rstrip('/')
SECT = set(sys.argv[2:]) or {'coin', 'convoy'}
W = 0.0005
FILES = {2: 'tr_main_leg2.39067.tsv.xz', 5: 'tr_main_leg5.43522.tsv.xz'}


def load(f):
    rows = []
    for i, line in enumerate(lzma.open(f, 'rt')):
        p = line.rstrip('\n').split('\t')
        if i == 0 or len(p) != 9:
            continue
        rows.append(dict(tag=p[0], th=int(p[2]), q=int(p[3]), beg=float(p[4]), com=float(p[5]), gs=float(p[6]), ge=float(p[7]), dn=float(p[8])))
    return rows


def cnt(a, lo, hi):
    """number of items of sorted list a with lo < x <= hi"""
    return bisect.bisect_right(a, hi) - bisect.bisect_right(a, lo)


class Ev:
    def __init__(self, rows):
        self.kinds = {}
        pr = [r for r in rows if r['q'] != 99]
        se = [r for r in rows if r['q'] == 99]
        self.Pend = sorted(r['ge'] for r in pr)
        self.Pend_q = collections.defaultdict(list)
        for r in pr:
            self.Pend_q[r['q']].append(r['ge'])
        for v in self.Pend_q.values():
            v.sort()
        self.Send = sorted(r['ge'] for r in se)
        self.allk = {}
        for k in ('com', 'dn', 'gs'):
            self.allk[k] = sorted(r[k] for r in rows)
        self.allk_q = {}
        for k in ('com', 'dn', 'gs'):
            d = collections.defaultdict(list)
            for r in rows:
                d[r['q']].append(r[k])
            for v in d.values():
                v.sort()
            self.allk_q[k] = d

    def other(self, k, lo, hi, q):
        return cnt(self.allk[k], lo, hi) - cnt(self.allk_q[k].get(q, []), lo, hi)

    def classify(self, t, q):
        """kind of coincidence for a (virtual) start at time t of a buffer on queue q"""
        if cnt(self.Pend, t - W, t) - cnt(self.Pend_q.get(q, []), t - W, t) > 0:
            return 1
        if cnt(self.Send, t - W, t) > 0:
            return 2
        if self.other('com', t - W, t, q) > 0:
            return 3
        if self.other('dn', t - W, t, q) > 0:
            return 4
        # a device start of another queue within +-0.5 ms; for the real start the buffer's own start is on its own queue and excluded
        if self.other('gs', t - W, t + W, q) > 0:
            return 5
        return 6


def central(rows, key):
    t0 = min(r['com'] for r in rows)
    t1 = max(r['dn'] for r in rows)
    a, b = t0 + 0.15 * (t1 - t0), t0 + 0.85 * (t1 - t0)
    return a, b, t0, t1


NAMES = {1: 'end of another prover queue', 2: 'end of a sealing buffer', 3: 'commit on another queue', 4: 'host DONE on another queue', 5: 'a start on another queue +-0.5 ms', 6: 'nothing'}


def part_a(leg, rows):
    ev = Ev(rows)
    a, b, _, _ = central(rows, 'gs')
    grp = {'q > 5 ms': lambda r: r['gs'] - r['com'] > 0.005, '0.5 < q <= 5 ms': lambda r: 0.0005 < r['gs'] - r['com'] <= 0.005, 'q <= 0.5 ms': lambda r: r['gs'] - r['com'] <= 0.0005}
    P = [r for r in rows if r['q'] != 99 and a <= r['gs'] < b]
    print('=== PART A, leg %d: %d prover starts in the central window ===' % (leg, len(P)))
    for gname, sel in grp.items():
        rs = [r for r in P if sel(r)]
        n = len(rs)
        meas = collections.Counter(ev.classify(r['gs'], r['q']) for r in rs)
        ctrl = collections.Counter()
        nc = 0
        for d in (-0.003, -0.0025, -0.002, -0.0015, -0.001, 0.001, 0.0015, 0.002, 0.0025, 0.003):
            for r in rs:
                ctrl[ev.classify(r['gs'] + d, r['q'])] += 1
                nc += 1
        print('  group %-16s n=%6d (%4.1f%% of starts)' % (gname, n, 100 * n / len(P)))
        for k in range(1, 7):
            m, c = 100 * meas[k] / n, 100 * ctrl[k] / nc
            real = ''
            if k < 6:
                real = ' REAL' if (m >= 1.5 * c and m - c >= 3.0) else ''
            print('     kind %d %-36s measured %5.1f%%   control %5.1f%%   ratio %5.2f   excess %+5.1f points%s' % (k, NAMES[k], m, c, m / c if c else float('nan'), m - c, real))
        if gname == 'q > 5 ms':
            noend = n - meas[1] - meas[2]
            print('     of the %d starts with no end in 0.5 ms before: kinds 3, 4, 5 hold %.1f%%, nothing %.1f%%' % (noend, 100 * (meas[3] + meas[4] + meas[5]) / noend, 100 * meas[6] / noend))


def merged_gaps(intervals, a, b, minlen):
    """gaps (start, end) of at least minlen where no interval is open, within [a, b]"""
    intervals.sort()
    gaps = []
    cur = None
    for s, e in intervals:
        if cur is None:
            cur = e
            continue
        if s > cur:
            if cur >= a and s <= b and s - cur >= minlen:
                gaps.append((cur, s))
        cur = max(cur, e)
    return gaps


def convoy_stats(rows, a, b, mode):
    """mode 'inflight': [com, ge] of every buffer; 'exec': [gs, ge].  Returns dict of statistics."""
    if mode == 'inflight':
        iv = [(r['com'], r['ge']) for r in rows if r['ge'] >= r['com']]
    else:
        iv = [(r['gs'], r['ge']) for r in rows if r['ge'] >= r['gs']]
    gaps = merged_gaps(iv, a, b, 0.001)
    endsq = collections.defaultdict(list)
    for r in rows:
        endsq[r['q'] if r['q'] == 99 else ('P', r['q'])].append(r['ge'])
    for v in endsq.values():
        v.sort()
    k1 = []
    for g0, g1 in gaps:
        k1.append(sum(1 for q, v in endsq.items() if cnt(v, g0 - 0.001, g0) > 0))
    P = [r for r in rows if r['q'] != 99 and a <= r['com'] < b]
    gends = sorted(g1 for g0, g1 in gaps)
    long_all = [r for r in P if r['gs'] - r['com'] > 0.005]
    inn = []
    for r in P:
        i = bisect.bisect_right(gends, r['com']) - 1
        inn.append(i >= 0 and r['com'] - gends[i] <= 0.005)
    nin = sum(inn)
    nlin = sum(1 for r, f in zip(P, inn) if f and r['gs'] - r['com'] > 0.005)
    return dict(ngap=len(gaps), glens=[g1 - g0 for g0, g1 in gaps], empty=sum(g1 - g0 for g0, g1 in gaps) / (b - a), k1=sum(k1) / len(k1) if k1 else float('nan'),
                nin=nin, share_in=nlin / nin if nin else float('nan'), base=len(long_all) / len(P), cover=nlin / len(long_all) if long_all else float('nan'), nP=len(P))


def shifted(rows, rng, t0, t1):
    span = t1 - t0
    offs = {}
    out = []
    for r in rows:
        key = ('S', r['th']) if r['q'] == 99 else ('P', r['q'])
        if key not in offs:
            offs[key] = rng.uniform(0, span)
        c2 = t0 + ((r['com'] - t0 + offs[key]) % span)
        dlt = c2 - r['com']
        out.append(dict(r, com=c2, gs=r['gs'] + dlt, ge=r['ge'] + dlt, dn=r['dn'] + dlt, beg=r['beg'] + dlt))
    return out


def part_b(leg, rows):
    a, b, t0, t1 = central(rows, 'com')
    print('=== PART B (convoy), leg %d: central window %.1f s ===' % (leg, b - a))
    # per-queue host gaps: next begin minus previous done on the same prover queue
    byq = collections.defaultdict(list)
    for r in rows:
        if r['q'] != 99:
            byq[r['q']].append(r)
    hg = []
    for q, v in byq.items():
        v.sort(key=lambda r: r['gs'])
        for x, y in zip(v, v[1:]):
            if a <= y['beg'] < b:
                g = y['beg'] - x['dn']
                if g > 0:
                    hg.append(g)
    hg.sort()
    pc = lambda p: hg[int(p * (len(hg) - 1))]
    print('  per-queue host gaps (next begin minus previous done, positive ones): n=%d  p25 %.2f ms  median %.2f ms  p75 %.2f ms  p90 %.1f ms' % (len(hg), 1e3 * pc(.25), 1e3 * pc(.5), 1e3 * pc(.75), 1e3 * pc(.9)))
    for mode in ('inflight', 'exec'):
        real = convoy_stats(rows, a, b, mode)
        rng = random.Random(45 + leg)
        nul = [convoy_stats(shifted(rows, rng, t0, t1), a, b, mode) for _ in range(20)]
        mean = lambda k: statistics.mean(x[k] for x in nul if x[k] == x[k])
        gl = sorted(real['glens'])
        med = gl[len(gl) // 2] if gl else float('nan')
        nlmed = statistics.mean(sorted(x['glens'])[len(x['glens']) // 2] for x in nul if x['glens'])
        print('  [%s] gaps >= 1 ms with nothing %s: n=%d, share of time %.2f%%, median length %.2f ms (null: n=%.0f, %.2f%%, median %.2f ms)' % (
            mode, 'in flight (committed to end)' if mode == 'inflight' else 'executing', real['ngap'], 100 * real['empty'], 1e3 * med, mean('ngap'), 100 * mean('empty'), 1e3 * nlmed))
        print('     B1 distinct queues with an end in the 1 ms before a gap start: %.2f (null %.2f), ratio %.2f' % (real['k1'], mean('k1'), real['k1'] / mean('k1')))
        print('     B2 median gap %.2f ms against host-gap p25 %.2f / p75 %.2f ms -> %s' % (1e3 * med, 1e3 * pc(.25), 1e3 * pc(.75), 'inside' if pc(.25) <= med <= pc(.75) else 'outside'))
        print('     B3 prover buffers committed in [gap end, +5 ms]: n=%d (null %.0f); long-waiter share %.1f%% (all prover buffers %.1f%%, ratio %.2f; null %.1f%%, ratio %.2f); they hold %.1f%% of all long waiters (null %.1f%%)' % (
            real['nin'], mean('nin'), 100 * real['share_in'], 100 * real['base'], real['share_in'] / real['base'], 100 * mean('share_in'), real['share_in'] / mean('share_in'), 100 * real['cover'], 100 * mean('cover')))


for leg, fn in FILES.items():
    rows = load(os.path.join(D, fn))
    print('##### leg %d: %d rows' % (leg, len(rows)))
    if 'coin' in SECT:
        part_a(leg, rows)
    if 'convoy' in SECT:
        part_b(leg, rows)


# ---- SUPPLEMENT 'supp' (NOT pre-registered; run after the pre-registered sections, labelled so in the handoff) ----
# For prover buffers with q > 5 ms and no end of any buffer on another queue in the 0.5 ms before their start: is the coincident start of another queue
# BEFORE (s - 0.5, s] or AFTER (s, s + 0.5], and are the partners themselves long waiters (released together) or not?
if 'supp' in SECT:
    for leg, fn in FILES.items():
        rows = load(os.path.join(D, fn))
        ev = Ev(rows)
        a, b, _, _ = central(rows, 'gs')
        PS = sorted((r['gs'], r['q'], r['gs'] - r['com']) for r in rows if r['q'] != 99)
        gsl = [x[0] for x in PS]
        base_long = sum(1 for x in PS if x[2] > 0.005) / len(PS)
        L = [r for r in rows if r['q'] != 99 and a <= r['gs'] < b and r['gs'] - r['com'] > 0.005 and ev.classify(r['gs'], r['q']) >= 3]
        n = len(L)

        def side(t, q, lo, hi):
            i, j = bisect.bisect_right(gsl, lo), bisect.bisect_right(gsl, hi)
            return [PS[k] for k in range(i, j) if PS[k][1] != q]

        pre = nxt = both = 0
        ctrl_pre = ctrl_nxt = ctrl_n = 0
        partners = []
        for r in L:
            p1 = side(r['gs'], r['q'], r['gs'] - W, r['gs'])
            p2 = side(r['gs'], r['q'], r['gs'], r['gs'] + W)
            pre += bool(p1)
            nxt += bool(p2)
            both += bool(p1 and p2)
            partners += [x[2] for x in p1 + p2]
            for d in (-0.003, -0.0025, -0.002, -0.0015, -0.001, 0.001, 0.0015, 0.002, 0.0025, 0.003):
                t = r['gs'] + d
                ctrl_pre += bool(side(t, r['q'], t - W, t))
                ctrl_nxt += bool(side(t, r['q'], t, t + W))
                ctrl_n += 1
        print('SUPP leg %d: long waiters with no end before them (kinds 3 to 6): n=%d; prover start of another queue in (s-0.5, s]: %.1f%% (control %.1f%%); in (s, s+0.5]: %.1f%% (control %.1f%%); both: %.1f%%' % (
            leg, n, 100 * pre / n, 100 * ctrl_pre / ctrl_n, 100 * nxt / n, 100 * ctrl_nxt / ctrl_n, 100 * both / n))
        print('     partners (prover starts of other queues within +-0.5 ms): %d, of which wait > 5 ms: %.1f%% (all prover buffers: %.1f%%)' % (
            len(partners), 100 * sum(1 for w in partners if w > 0.005) / max(1, len(partners)), 100 * base_long))
