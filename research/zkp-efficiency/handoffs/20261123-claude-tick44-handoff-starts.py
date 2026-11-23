"""Tick 44 (queue item 60): cross-lane hand-off starts, measured on legs 2 (six lanes) and 5 (eight lanes), against tick 36's replay.
Standard library only.  Usage:
    python3 -I -B this.py <results/zk60_lanes_trace_20261121/raw> <path of 20261122-claude-tick36-launch-wait.py> <path of 20261121-claude-tick35-replay.py> [meas|replay|both]
Tick 36's script is executed unchanged except for two text patches that record each buffer's end time and hand back the per-buffer state (no change of
the model).  Lane = prover queue (one queue per lane in legs 2 and 5: 6 and 8 prover queues); the sealing buffers all sit on queue 99, so a sealing
buffer has no lane in the trace; in the replay a sealing buffer has a lane but is given queue 99 for a like-for-like count.
Quantity: for a buffer start (gpu_start) at time s on queue q, count the buffers on another queue whose gpu_end lies in (s - w, s] (a hand-off lag in
[0, w)) and in (s, s + w] (the mirror: an end AFTER the start cannot have caused it; it is the chance control).  w = 0.5 ms.  Lag bins of 0.5 ms
from -2 ms to +3 ms are also printed.
"""
import bisect
import collections
import sys

raw = sys.argv[1].rstrip('/')
t36_path, t35_path = sys.argv[2], sys.argv[3]
SECT = set(sys.argv[4:]) or {'meas', 'replay'}
if 'both' in SECT:
    SECT |= {'meas', 'replay'}

src = open(t36_path).read()
src = src.replace("ivs_dev.append((gsx, now))", "ivs_dev.append((gsx, now)); st[key]['ge'] = now")
src = src.replace("    return comps, ivs_dev, inflight, qblock", "    LAST[0] = (st, comps)\n    return comps, ivs_dev, inflight, qblock")
# stage 2 patches (inactive while ADM is None): a buffer whose drawn wait exceeds THR waits in a list and is released when a buffer ends
src = src.replace("    pend = [0]\n", "    pend = [0]\n    LAUNCHED = set()\n    waiting = []\n", 1)
src = src.replace("                push(now + q, 'launch', l, req, kk)\n",
                  "                if ADM and q > THR and len(running) > 0:\n"
                  "                    waiting.append((now, q, l, req, kk))\n"
                  "                    if ADM[1]:\n"
                  "                        push(now + q, 'launch', l, req, kk)\n"
                  "                else:\n"
                  "                    push(now + q, 'launch', l, req, kk)\n", 1)
src = src.replace("                l, req, kk = a\n                pend[0] -= 1\n",
                  "                l, req, kk = a\n                if (l, req, kk) in LAUNCHED:\n                    continue\n                LAUNCHED.add((l, req, kk))\n"
                  "                waiting[:] = [w for w in waiting if w[2:] != (l, req, kk)]\n                pend[0] -= 1\n", 1)
src = src.replace("                push(now + lane_state[l]['bufs'][kk]['dl'], 'done', l, req, kk)\n",
                  "                push(now + lane_state[l]['bufs'][kk]['dl'], 'done', l, req, kk)\n"
                  "            if ADM and waiting:\n"
                  "                nrel = len(waiting) if ADM[0] == 'all' else min(len(fin), len(waiting))\n"
                  "                for _ in range(nrel):\n"
                  "                    w_ = waiting.pop(0)\n"
                  "                    push(now, 'launch', w_[2], w_[3], w_[4])\n", 1)
assert src.count("LAUNCHED") == 3 and "nrel" in src and "waiting.append" in src
assert "if (l, req, kk) in LAUNCHED" in src
LAST = [None]
sys.argv = [t36_path, raw, t35_path, 'none']
ns = {'__name__': 'tick36', 'LAST': LAST, 'ADM': None, 'THR': 0.0005}
exec(compile(src, t36_path, 'exec'), ns)
legs, load, window_rows, tab2, simulate, MEAS, RATES, stats = (ns[k] for k in ('legs', 'load', 'window_rows', 'tab2', 'simulate', 'MEAS', 'RATES', 'stats'))

W = 0.0005
BINS = [(-0.002 + 0.0005 * i, -0.002 + 0.0005 * (i + 1)) for i in range(10)]  # lag = s - e, in seconds (positive: the end came first)


class Ends:
    """ends of buffers: all, by queue; count in an interval excluding the start's own queue"""

    def __init__(self, ends):  # ends: list of (time, queue, cls)
        self.byq = collections.defaultdict(list)
        self.all = sorted(e[0] for e in ends)
        self.byq_cls = collections.defaultdict(list)
        for t, q, c in ends:
            self.byq[q].append(t)
            self.byq_cls[(q, c)].append(t)
        for v in self.byq.values():
            v.sort()
        for v in self.byq_cls.values():
            v.sort()
        self.cls = {c: sorted(t for t, q, cc in ends if cc == c) for c in ('P', 'S')}

    def count(self, lo, hi, q, ends_cls=None):
        """ends with lo < t <= hi on queues other than q, optionally only of class ends_cls"""
        if ends_cls is None:
            A = self.all
            n = bisect.bisect_right(A, hi) - bisect.bisect_right(A, lo)
            B = self.byq.get(q, [])
            n -= bisect.bisect_right(B, hi) - bisect.bisect_right(B, lo)
            return n
        A = self.cls[ends_cls]
        n = bisect.bisect_right(A, hi) - bisect.bisect_right(A, lo)
        B = self.byq_cls.get((q, ends_cls), [])
        n -= bisect.bisect_right(B, hi) - bisect.bisect_right(B, lo)
        return n


VARIANTS = (
    ('P starts after P ends of other lanes (clean lane identity)', 'P', 'P'),
    ('P starts after any end on another queue (P of other lanes, sealing)', 'P', None),
    ('S starts after P ends (sealing queue 99 after a prover buffer)', 'S', 'P'),
    ('all starts after any end on another queue', None, None),
)


def analyse(starts, ends):
    """starts: list of (s, queue, cls) inside the window; ends: all (e, queue, cls).  Returns {variant: (n, hand, mirror, lagbins)}."""
    E = Ends(ends)
    out = {}
    for name, sc, ec in VARIANTS:
        n = hand = mirror = 0
        bins = [0] * len(BINS)
        for s, q, c in starts:
            if sc is not None and c != sc:
                continue
            n += 1
            if E.count(s - W, s, q, ec) > 0:
                hand += 1
            if E.count(s, s + W, q, ec) > 0:
                mirror += 1
            for i, (a, b) in enumerate(BINS):
                # lag = s - e in [a, b)  <=>  e in (s - b, s - a]
                if E.count(s - b, s - a, q, ec) > 0:
                    bins[i] += 1
        out[name] = (n, hand, mirror, bins)
    return out


def measured(L):
    rows = load(L)
    wr = window_rows(L, rows)
    starts = [(r['gs'], r['q'], 'S' if r['tag'] == 'wprod' else 'P') for r in wr]
    ends = [(r['ge'], r['q'], 'S' if r['tag'] == 'wprod' else 'P') for r in rows]
    return analyse(starts, ends)


def replay(lanes, tab, seed):
    M = MEAS[lanes]
    comps, ivs, inf, qb = simulate(lanes, M['nreq'], RATES[lanes], tab, seed=seed, hp=M['hp'], hs=M['hp'])
    st, comps = LAST[0]
    N, T = M['N'], M['T']
    ct = sorted(c[0] for c in comps)
    t0, t1 = ct[N - 1], ct[N + T - 1]
    starts, ends = [], []
    for (l, req, k), v in st.items():
        if 'gs' not in v or 'ge' not in v:
            continue
        q = 99 if v['cls'] == 'S' else l
        ends.append((v['ge'], q, v['cls']))
        if t0 <= v['beg'] < t1:
            starts.append((v['gs'], q, v['cls']))
    return analyse(starts, ends)


def pr(tag, res):
    print('--- %s' % tag)
    for name, _, _ in VARIANTS:
        n, h, m, bins = res[name]
        print('  %-70s n=%6d  hand-off (lag 0 to 0.5 ms) %5.1f%%  mirror (end 0 to 0.5 ms after) %5.1f%%  ratio %.2f' % (name, n, 100 * h / n, 100 * m / n, h / max(m, 1)))
        print('      lag bins (ms, s minus e): ' + '  '.join('[%+.1f,%+.1f) %.1f%%' % (1e3 * a, 1e3 * b, 100 * x / n) for (a, b), x in zip(BINS, bins)))


def merge(rs):
    out = {}
    for name, _, _ in VARIANTS:
        n = sum(r[name][0] for r in rs)
        h = sum(r[name][1] for r in rs)
        m = sum(r[name][2] for r in rs)
        bins = [sum(r[name][3][i] for r in rs) for i in range(len(BINS))]
        out[name] = (n, h, m, bins)
    return out


if 'wait' in SECT:
  for ECLS, ETXT in (('P', 'other-lane prover ends only'), (None, 'any end on another queue, sealing included')):
      # among prover starts, split by committed-to-start wait q = gs - com: is a long wait ended by another lane's buffer end?
      print('[' + ETXT + ']'); print('=== waiting buffers (committed-to-start over 0.5 ms) against the rest, prover buffers, hand-off = other-lane P end in (s-0.5 ms, s]; mirror = in (s, s+0.5 ms] ===')
      for lg, nm in ((legs[1], 'leg 2, six lanes'), (legs[4], 'leg 5, eight lanes')):
          rows = load(lg)
          wr = [r for r in window_rows(lg, rows) if r['tag'] != 'wprod']
          E = Ends([(r['ge'], r['q'], 'S' if r['tag'] == 'wprod' else 'P') for r in rows if ECLS is None or r['tag'] != 'wprod'])
          for lab, sel in (('q <= 0.5 ms', lambda r: r['gs'] - r['com'] <= W), ('0.5 < q <= 5 ms', lambda r: W < r['gs'] - r['com'] <= 0.005), ('q > 5 ms', lambda r: r['gs'] - r['com'] > 0.005)):
              rs = [r for r in wr if sel(r)]
              n = len(rs)
              h = sum(1 for r in rs if E.count(r['gs'] - W, r['gs'], r['q'], ECLS) > 0)
              m = sum(1 for r in rs if E.count(r['gs'], r['gs'] + W, r['q'], ECLS) > 0)
              b = [sum(1 for r in rs if E.count(r['gs'] - hi, r['gs'] - lo, r['q'], ECLS) > 0) / n for lo, hi in ((0.0005, 0.001), (0.001, 0.0015), (0.0015, 0.002), (0.002, 0.0025), (0.0025, 0.003))]
              bg = sum(b) / len(b)
              print('  %s | %-16s n=%6d (%4.1f%% of starts)  hand-off %5.1f%%  mirror %5.1f%%  flat background (lags 0.5 to 3 ms) %5.1f%%  -> hand-off fraction %.1f%%' % (
                  nm, lab, n, 100 * n / len(wr), 100 * h / n, 100 * m / n, 100 * bg, 100 * (h / n - bg) / (1 - bg)))

results = {}
LEVELS = {6: [22.7, 16.4, 20.7, 27.6], 8: [26.0, 8.9, 13.2, 24.8]}  # measured level shares 0..3 (tick 36 section 3, DERIVED from the traces)
if 'adm' in SECT:
    run = ns['run']
    fmt = ns['fmt']
    print('=== STAGE 2: tick 36 rule, but a buffer with drawn wait over 0.5 ms waits to be released by a buffer end (no refit; three seeds) ===')
    for lanes, M in ((6, MEAS[6]), (8, MEAS[8])):
        print('lanes %d; measured: rate %.2f empty %.1f%% >=3 %.1f%% none %.1f%% variance %.2f; levels 0..3 %s' % (
            lanes, M['rate'], 100 * M['empty'], 100 * M['hi'], 100 * M['none'], M['vr'], LEVELS[lanes]))
        for nm, mode in (('tick 36 rule (timed)', None), ('release ALL waiting at each end, no timeout', ('all', False)),
                         ('release ONE (FIFO) per end, no timeout', ('one', False)), ('release ALL at an end, or at the drawn time', ('all', True)),
                         ('release ONE at an end, or at the drawn time', ('one', True))):
            ns['ADM'] = mode
            m = run(lanes, tab2, hp=M['hp'], hs=M['hp'])
            lv = [0.0] * 4
            for sd in range(3):
                comps, ivs, inf, qb = simulate(lanes, M['nreq'], RATES[lanes], tab2, seed=sd, hp=M['hp'], hs=M['hp'])
                s_ = stats(comps, ivs, inf, lanes, M['N'], M['T'])
                for k in range(4):
                    lv[k] += 100 * s_['lev'].get(k, 0.0) / 3
            d = lambda a, b: 100 * (a / b - 1)
            dl = [x - y for x, y in zip(lv, LEVELS[lanes])]
            print('  %-46s %s | q/block %.1f | levels 0..3 %s | diff points %s | rate %+.0f%% empty %+.0f%% var %+.0f%%' % (
                nm, fmt(m), m['q'], ['%.1f' % x for x in lv], ['%+.1f' % x for x in dl], d(m['rate'], M['rate']), d(m['empty'], M['empty']), d(m['vr'], M['vr'])))
    ns['ADM'] = None

if 'meas' in SECT:
    print('=== MEASURED (window rows by begin time, as in tick 36) ===')
    for lg, nm in ((legs[1], 'leg 2, six lanes'), (legs[4], 'leg 5, eight lanes'), (legs[0], 'leg 1, one lane (control: no other lane)')):
        r = measured(lg)
        results[nm] = r
        pr(nm, r)
if 'replay' in SECT:
    print('\n=== REPLAY with the tick 36 rule (three seeds pooled) ===')
    for lanes, nm in ((6, 'replay six lanes'), (8, 'replay eight lanes')):
        rs = [replay(lanes, tab2, sd) for sd in range(3)]
        r = merge(rs)
        results[nm] = r
        pr(nm, r)
    print('\n=== measured over replay, hand-off share ===')
    for a, b in (('leg 2, six lanes', 'replay six lanes'), ('leg 5, eight lanes', 'replay eight lanes')):
        if a in results and b in results:
            for name, _, _ in VARIANTS:
                ma = results[a][name]
                mb = results[b][name]
                sa, sb = ma[1] / ma[0], mb[1] / mb[0]
                xa, xb = ma[2] / ma[0], mb[2] / mb[0]
                print('  %s | %-62s measured %5.1f%% replay %5.1f%% -> x%.2f; excess over mirror: measured %+.1f points, replay %+.1f points' % (a, name[:62], 100 * sa, 100 * sb, sa / sb, 100 * (sa - xa), 100 * (sb - xb)))
