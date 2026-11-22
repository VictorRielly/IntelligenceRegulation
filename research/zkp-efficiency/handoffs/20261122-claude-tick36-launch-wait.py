"""Tick 36 (queue item 59): a launch-wait rule for the tick 35 replay, fitted on leg 2, tested on leg 5 (eight lanes) and leg 4.
Standard library only.  Usage:
    python3 -I -B this.py <results/zk60_lanes_trace_20261121/raw> <path of 20261121-claude-tick35-replay.py> [fit|six|eight|diag|leg4 ...]
The tick 35 script is executed (with no section selected) to get its templates from leg 1, its stats() and its constants; nothing in it is changed.
Model change: the replay's launch step (leg 1's committed-to-start latency, no waiting) is replaced by a draw of committed-to-start time q
from leg 2's measured q, binned by (class, buffers executing at commit, buffers committed-but-not-started at commit).  The device model
(processor sharing with R(k)), the host gaps and everything else are tick 35's.
"""
import bisect
import collections
import heapq
import math
import os
import random
import sys

raw = sys.argv[1].rstrip('/')
replay_path = sys.argv[2]
SECT = set(sys.argv[3:]) or {'fit', 'six', 'eight', 'diag', 'leg4'}

sys.argv = [replay_path, raw, 'none']
ns = {'__name__': 'replay35'}
exec(compile(open(replay_path).read(), replay_path, 'exec'), ns)
load, legs, TEMPL, stats, fmt, MEAS, RATES = (ns[k] for k in ('load', 'legs', 'TEMPL', 'stats', 'fmt', 'MEAS', 'RATES'))


# ------------------------------------------------------------------ the fit: q by state at commit, from a measured leg
def state_counts(rows):
    gs = sorted(r['gs'] for r in rows)
    ge = sorted(r['ge'] for r in rows)
    cm = sorted(r['com'] for r in rows)

    def e_at(t):
        return bisect.bisect_right(gs, t) - bisect.bisect_right(ge, t)

    def p_at(t):
        return bisect.bisect_right(cm, t) - bisect.bisect_right(gs, t)
    return e_at, p_at


def window_rows(L, rows):
    N, T = L['N'], L['timed']
    c = sorted(x['t_abs'] for x in L['completions'])
    t0, t1 = c[N - 1], c[N + T - 1]
    return [r for r in rows if t0 <= r['beg'] < t1]


class Table:
    """q draws by (class, e, p); e capped at 5, p at 4; a bin with fewer than 30 rows falls back to p-1, then e-1.  mode: 'sample' or 'mean'."""

    def __init__(self, L, rows, use_p=True, use_e=True, min_n=30):
        e_at, p_at = state_counts(rows)
        self.bins = collections.defaultdict(list)
        self.min_n = min_n
        self.use_p, self.use_e = use_p, use_e
        for r in window_rows(L, rows):
            cls = 'S' if r['tag'] == 'wprod' else 'P'
            t = r['com'] - 1e-7
            e = min(e_at(t), 5) if use_e else 0
            p = min(p_at(t), 4) if use_p else 0
            self.bins[(cls, e, p)].append(r['gs'] - r['com'])
        self.mean = {k: sum(v) / len(v) for k, v in self.bins.items()}
        self.cache = {}

    def lookup(self, cls, e, p):
        e = min(e, 5) if self.use_e else 0
        p = min(p, 4) if self.use_p else 0
        key = (cls, e, p)
        if key in self.cache:
            return self.cache[key]
        k = key
        while len(self.bins.get(k, ())) < self.min_n:
            c, ee, pp = k
            if pp > 0:
                pp -= 1
            elif ee > 0:
                ee -= 1
            else:
                break
            k = (c, ee, pp)
        self.cache[key] = k
        return k

    def draw(self, rng, cls, e, p, mode):
        k = self.lookup(cls, e, p)
        if mode == 'mean':
            return self.mean[k]
        v = self.bins[k]
        return v[rng.randrange(len(v))]


# ------------------------------------------------------------------ simulation: tick 35's, with the launch step replaced
def simulate(lanes, nreq, rates, tab, mode='sample', hp=1.0, hs=1.0, ws=0.75, stagger=0.3, seed=0, base_lat=False, qscale=1.0):
    rng = random.Random(seed)
    R = lambda k: rates[min(k, 4)] if k > 0 else 0.0
    order = list(range(lanes))
    rng.shuffle(order)
    heap = []
    cnt = [0]

    def push(t, typ, *a):
        cnt[0] += 1
        heapq.heappush(heap, (t, cnt[0], typ, a))

    st = {}
    running = {}
    comps = []
    ivs_dev = []
    inflight = collections.defaultdict(list)
    lane_state = {l: dict(req=0) for l in range(lanes)}
    pend = [0]

    def start_request(l, t):
        ls = lane_state[l]
        ti = (order[l] + ls['req'] * 5 + seed) % 6
        T = TEMPL[ti]
        ls.update(tmpl=ti, bufs=T['bufs'], n=len(T['bufs']), ndone=0, dep=collections.defaultdict(list))
        for k, b in enumerate(T['bufs']):
            ls['dep'][b['en']].append(k)
        for k in ls['dep'][-1]:
            sched_begin(l, ls['req'], k, t)

    def sched_begin(l, req, k, tdone):
        ls = lane_state[l]
        b = ls['bufs'][k]
        g = b['gap'] * (hp if b['cls'] == 'P' else hs)
        if b['en'] == -1:
            g = b['gap'] * hs
        if (l, req, k) in st:
            return
        st[(l, req, k)] = dict(cls=b['cls'])
        push(tdone + g, 'commit', l, req, k)

    nextid = [0]
    now = 0.0
    for l in range(lanes):
        push(l * stagger, 'req', l)
    while heap or running:
        k = len(running)
        r = R(k) / k if k else 0.0
        tf = None
        if k:
            m = min(running.items(), key=lambda kv: kv[1][0])
            tf = now + m[1][0] / r
        if heap and (tf is None or heap[0][0] <= tf):
            t, _, typ, a = heapq.heappop(heap)
            dt = t - now
            if dt > 0 and k:
                for v in running.values():
                    v[0] -= r * dt
            now = t
            if typ == 'req':
                start_request(a[0], now)
            elif typ == 'commit':
                l, req, kk = a
                b = lane_state[l]['bufs'][kk]
                st[(l, req, kk)]['beg'] = now
                q = tab.draw(rng, b['cls'], len(running), pend[0], mode) * qscale
                if base_lat:
                    q = max(q, b['lat'])
                pend[0] += 1
                push(now + q, 'launch', l, req, kk)
            elif typ == 'launch':
                l, req, kk = a
                pend[0] -= 1
                b = lane_state[l]['bufs'][kk]
                w = b['work'] * (ws if b['cls'] == 'S' else 1.0)
                nextid[0] += 1
                running[nextid[0]] = [w, (l, req, kk)]
                st[(l, req, kk)]['gs'] = now
            elif typ == 'done':
                l, req, kk = a
                ls = lane_state[l]
                b = ls['bufs'][kk]
                s = st[(l, req, kk)]
                if b['cls'] == 'P':
                    inflight[l].append((s['beg'], now))
                ls['ndone'] += 1
                for k2 in ls['dep'].get(kk, []):
                    sched_begin(l, req, k2, now)
                if ls['ndone'] == ls['n']:
                    push(now + TEMPL[ls['tmpl']]['tail'] * hs, 'complete', l, req)
            elif typ == 'complete':
                l, req = a
                comps.append((now, l))
                ls = lane_state[l]
                ls['req'] += 1
                if ls['req'] < nreq:
                    start_request(l, now)
        else:
            dt = tf - now
            for v in running.values():
                v[0] -= r * dt
            t_start = now
            now = tf
            fin = [i for i, v in running.items() if v[0] <= 1e-12]
            for i in fin:
                rem, key = running.pop(i)
                gsx = st[key]['gs']
                ivs_dev.append((gsx, now))
                l, req, kk = key
                push(now + lane_state[l]['bufs'][kk]['dl'], 'done', l, req, kk)
    comps.sort()
    qs = [(v['gs'] - v['beg']) for v in st.values() if 'gs' in v and 'beg' in v and v['cls'] == 'P']
    qblock = 1e3 * sum(qs) / len(qs) * 18.5
    return comps, ivs_dev, inflight, qblock


def run(lanes, tab, seeds=3, **kw):
    M = MEAS[lanes]
    out = []
    for sd in range(seeds):
        comps, ivs, inf, qb = simulate(lanes, M['nreq'], RATES[lanes], tab, seed=sd, **kw)
        s = stats(comps, ivs, inf, lanes, M['N'], M['T'])
        s['q'] = qb
        out.append(s)
    m = {k: sum(o[k] for o in out) / len(out) for k in ('rate', 'empty', 'hi', 'none', 'vr', 'ind', 'q')}
    m['spread'] = (min(o['rate'] for o in out), max(o['rate'] for o in out))
    return m


def line(tag, m, meas=None):
    s = '%-46s %s | q/block %.1f ms [rate range %.2f to %.2f]' % (tag, fmt(m), m['q'], m['spread'][0], m['spread'][1])
    if meas:
        d = lambda a, b: 100 * (a / b - 1)
        s += ' || vs measured: rate %+.0f%%, empty %+.0f%%, >=3 %+.0f%%, variance %+.0f%%, none %+.0f%%' % (
            d(m['rate'], meas['rate']), d(m['empty'], meas['empty']), d(m['hi'], meas['hi']), d(m['vr'], meas['vr']), d(m['none'], meas['none']))
        ok = all(abs(x) <= 10 for x in (d(m['rate'], meas['rate']), d(m['empty'], meas['empty']), d(m['vr'], meas['vr'])))
        s += ' | within 10%% on rate, empty, variance: %s' % ('YES' if ok else 'no')
    print(s)


L2, L4, L5 = legs[1], legs[3], legs[4]
rows2 = load(L2)
tab2 = Table(L2, rows2)
tab2_e = Table(L2, rows2, use_p=False)
tab2_p = Table(L2, rows2, use_e=False)

if 'fit' in SECT:
    print('=== the fit: leg 2 q (ms) by (class, buffers executing, committed-not-started at commit); bins with at least 30 rows ===')
    for k in sorted(tab2.bins):
        v = sorted(tab2.bins[k])
        if len(v) >= 30:
            print('  %s e=%d p=%d: n=%5d mean %6.2f median %6.2f p90 %6.2f' % (k[0], k[1], k[2], len(v), 1e3 * sum(v) / len(v), 1e3 * v[len(v) // 2], 1e3 * v[int(0.9 * len(v))]))
    # how much of the variance of q does the table carry (leg 2, by class): R^2 on the bin means, and on log q
    for nm, tb in (('e and p', tab2), ('e only', tab2_e), ('p only', tab2_p)):
        ss = tt = 0.0
        allq = [x for v in tb.bins.values() for x in v]
        mu = sum(allq) / len(allq)
        for k, v in tb.bins.items():
            m = tb.mean[k]
            ss += sum((x - m) ** 2 for x in v)
        tt = sum((x - mu) ** 2 for x in allq)
        print('  share of q variance in leg 2 explained by the bin means (%s): %.1f%%' % (nm, 100 * (1 - ss / tt)))
    # the same table's out-of-sample check on leg 5's own q (no simulation): leg 5 rows, state at commit, predicted mean q
    for lg, nm in ((legs[4], 'leg 5 (8 lanes)'), (legs[3], 'leg 4 (shared queue)')):
        rows = load(lg)
        e_at, p_at = state_counts(rows)
        wr = window_rows(lg, rows)
        pred = act = 0.0
        npb = 0
        for r in wr:
            if r['tag'] == 'wprod':
                continue
            t = r['com'] - 1e-7
            k = tab2.lookup('P', e_at(t), p_at(t))
            pred += tab2.mean[k]
            act += r['gs'] - r['com']
            npb += 1
        print('  %s: prover buffers %d, measured mean q %.2f ms, leg-2 table at the measured state %.2f ms (ratio %.2f); per block x18.5: %.1f vs %.1f ms'
              % (nm, npb, 1e3 * act / npb, 1e3 * pred / npb, pred / act, 1e3 * act / npb * 18.5, 1e3 * pred / npb * 18.5))

if 'six' in SECT:
    print('\n=== six lanes (leg 2; the fit leg).  Tick 35 base without the rule: rate 49.85, empty 16.7%, >=3 40.3%, none 18.5%, variance 1.88, q/block 12.3 ms ===')
    M = MEAS[6]
    for tag, tb, kw in (('table e,p, sampled', tab2, {}), ('table e,p, bin means', tab2, dict(mode='mean')),
                        ('table e only, sampled', tab2_e, {}), ('table p only, sampled', tab2_p, {}),
                        ('table e,p, sampled, host stretch 1.0', tab2, dict(hp=1.0, hs=1.0)),
                        ('table e,p, sampled, sealing x1.0', tab2, dict(ws=1.0))):
        kw2 = dict(hp=M['hp'], hs=M['hp'])
        kw2.update(kw)
        line(tag, run(6, tb, **kw2), M)

if 'eight' in SECT:
    print('\n=== eight lanes (leg 5; NOT used in the fit; R(k) and host stretch 1.603 are leg 5 measurements, as in tick 35) ===')
    M = MEAS[8]
    for tag, tb, kw in (('table e,p (leg 2), sampled', tab2, {}), ('table e,p (leg 2), bin means', tab2, dict(mode='mean')),
                        ('table e only (leg 2)', tab2_e, {}), ('table p only (leg 2)', tab2_p, {})):
        kw2 = dict(hp=M['hp'], hs=M['hp'])
        kw2.update(kw)
        line(tag, run(8, tb, **kw2), M)
    # in-sample reference: the table fitted on leg 5 itself, to see what a perfect q rule could do in the same model
    tab5 = Table(L5, load(L5))
    line('table e,p fitted on leg 5 itself (reference)', run(8, tab5, hp=M['hp'], hs=M['hp']), M)

if 'diag' in SECT:
    print('\n=== which input is still missing: six lanes with the rule, one change at a time (diagnostic, sampled table) ===')
    M = MEAS[6]
    for tag, kw in (('rule + gaps x1.4', dict(hp=1.4, hs=1.4)), ('rule + gaps x1.0', dict(hp=1.0, hs=1.0)),
                    ('rule x0.5', dict(qscale=0.5)), ('rule x1.5', dict(qscale=1.5))):
        kw2 = dict(hp=M['hp'], hs=M['hp'])
        kw2.update(kw)
        line(tag, run(6, tab2, **kw2), M)
    # level shares (buffers executing) of the replay with the rule against leg 2 and leg 5
    for lanes, lg, tag in ((6, 2, 'six lanes'), (8, 5, 'eight lanes')):
        Mx = MEAS[lanes]
        comps, ivs, inf, qb = simulate(lanes, Mx['nreq'], RATES[lanes], tab2, seed=0, hp=Mx['hp'], hs=Mx['hp'])
        s_ = stats(comps, ivs, inf, lanes, Mx['N'], Mx['T'])
        print('replay with the rule, %s, levels (share of window): %s; max level %d' % (tag, ', '.join('%d: %.1f%%' % (k, 100 * v) for k, v in s_['lev'].items() if v > 0.001), max(s_['lev'])))
        Lx = legs[lg - 1]
        rx = load(Lx)
        a0 = sorted(x['t_abs'] for x in Lx['completions'])
        a0, a1 = a0[Lx['N'] - 1], a0[Lx['N'] + Lx['timed'] - 1]
        ev = []
        for r in rx:
            a, b = max(r['gs'], a0), min(r['ge'], a1)
            if b > a:
                ev += [(a, 1), (b, -1)]
        ev.sort()
        lev = collections.defaultdict(float)
        k = 0
        last = a0
        for t, d in ev:
            lev[k] += t - last
            last = t
            k += d
        lev[k] += a1 - last
        print('measured, leg %d, levels: %s; max level %d' % (lg, ', '.join('%d: %.1f%%' % (kk, 100 * v / (a1 - a0)) for kk, v in sorted(lev.items()) if v / (a1 - a0) > 0.001), max(lev)))

if 'leg4' in SECT:
    print('\n=== leg 4 (shared queue): what the rule can and cannot say ===')
    rows4 = load(L4)
    wr = window_rows(L4, rows4)
    qs = collections.Counter((r['q'], r['tag'] == 'wprod') for r in wr)
    print('queue ids in the leg 4 window (queue, is-sealing): ' + ', '.join('%s: %d' % (k, v) for k, v in sorted(qs.items())))
    w = [r['com'] - r['beg'] for r in wr if r['tag'] != 'wprod']
    print('begin-to-committed (w) for prover buffers: mean %.2f ms, p90 %.2f ms, p99 %.2f ms' % (1e3 * sum(w) / len(w), 1e3 * sorted(w)[int(.9 * len(w))], 1e3 * sorted(w)[int(.99 * len(w))]))
    # in-queue order: on the shared queue a buffer cannot start before its predecessor on that queue ended
    pr = sorted((r for r in wr if r['tag'] != 'wprod'), key=lambda r: r['com'])
    overl = 0
    for a, b in zip(pr, pr[1:]):
        if b['gs'] < a['ge'] - 1e-6:
            overl += 1
    print('prover buffers whose start precedes the previous commit-order buffer\'s end: %d of %d' % (overl, len(pr) - 1))
