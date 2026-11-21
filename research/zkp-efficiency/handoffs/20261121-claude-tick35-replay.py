"""Tick 35 (queue item 57): replay of the six-lane stream from the one-lane trace.
Standard library only; python3 -I -B this.py <results/zk60_lanes_trace_20261121/raw> [section ...]
Sections: tmpl (template statistics), base (replay vs leg 2 and leg 5), sens (sensitivity of the replay), diag (levels, queue time),
cand (candidates i to v).  No GPU, no build; about 1 to 3 minutes.

Model (all inputs from the traced legs; nothing fitted to leg 2 except where a line says "variant"):
 * A request is a dependency list taken from leg 1 (the one-lane trace, requests 2 to 7 between completions k-1 and k):
   buffer i has an ENABLER (the buffer of the same class and thread whose done time is within 3 ms of the latest done time
   before i's begin, else the latest-done buffer; or the previous completion for the first ones) and a GAP = begin_i - done_enabler.
   The host gap is replayed as gap * h (h = host stretch), the launch latency (gpu_start - committed), the done latency
   (done - gpu_end) as measured at one lane, the last buffer's tail up to the request completion as measured.
 * Device: processor sharing. With k buffers executing (any queue, sealing included) the device does R(k) solo-seconds of work
   per second, shared equally; a buffer of solo time s finishes when its share of work reaches s.  R(k) from item 56 (c).
   Optional cap C on buffers executing at once (the rest wait in first-in-first-out order).
 * Lanes: each lane runs its requests back to back; lane j's first request starts j * 0.300 s after the first (the stagger).
 * Window as in trace_check.py: from completion 6 to completion 54 (leg 2) of the lanes together; rate = 48 * 128 / window.
"""
import bisect
import collections
import heapq
import json
import lzma
import math
import os
import random
import re
import sys

raw = sys.argv[1].rstrip('/')
SECT = set(sys.argv[2:]) or {'tmpl', 'base', 'sens', 'diag', 'cand'}
legs = []
for name in ('tr_leg1', 'tr_main'):
    legs += json.load(open('%s/%s/t2_results.json' % (raw, name)))['legs']


def load(L):
    name = '%s/traces/%s.%d.tsv.xz' % (raw, os.path.basename(L['trace_prefix']), L['server_pid'])
    rows = []
    with lzma.open(name, 'rt') as f:
        h = f.readline().rstrip('\n').split('\t')
        for line in f:
            p = line.rstrip('\n').split('\t')
            if len(p) != len(h):
                continue
            rows.append(dict(tag=p[0], det=p[1], th=int(p[2]), q=int(p[3]), beg=float(p[4]), com=float(p[5]),
                             gs=float(p[6]), ge=float(p[7]), dn=float(p[8])))
    return rows


def label(r):
    if r['tag'] == 'batch':
        m = re.match(r'slot (\d+)', r['det'])
        return 'slot%02d' % int(m.group(1)) if m else 'batch?'
    if r['tag'] in ('gather', 'commit'):
        m = re.match(r'rows=(\d+)', r['det'])
        return '%s%s' % (r['tag'], m.group(1)) if m else r['tag']
    return r['tag']


# ---------------------------------------------------------------- templates from leg 1
L1 = legs[0]
rows1 = load(L1)
c1 = sorted(x['t_abs'] for x in L1['completions'])
rows1.sort(key=lambda r: r['beg'])


def make_template(i):
    """Request between completion i-1 and i of leg 1 (i = 1..6)."""
    ts, te = c1[i - 1], c1[i]
    rs = [r for r in rows1 if ts <= r['beg'] < te]
    n = len(rs)
    dones = [r['dn'] for r in rs]
    out = []
    for k, r in enumerate(rs):
        cls = 'S' if r['tag'] == 'wprod' else 'P'
        # candidates: earlier buffers (in begin order) whose done <= begin
        best = -1
        bd = ts
        for j in range(k - 1, -1, -1):
            if dones[j] <= r['beg'] + 1e-9 and dones[j] > bd:
                best, bd = j, dones[j]
        # prefer the same class and thread predecessor when it is within 3 ms of the latest done
        for j in range(k - 1, -1, -1):
            same = (rs[j]['tag'] == 'wprod') == (r['tag'] == 'wprod') and rs[j]['th'] == r['th']
            if same and dones[j] <= r['beg'] + 1e-9:
                if dones[j] >= bd - 0.003:
                    best, bd = j, dones[j]
                break
        out.append(dict(cls=cls, lab=label(r), th=r['th'], en=best, gap=r['beg'] - bd, lat=r['gs'] - r['com'],
                        work=r['ge'] - r['gs'], dl=r['dn'] - r['ge']))
    last_done = max(dones)
    tail = te - last_done
    # block starts: a prover gather2504 that follows slot22 in the prover chain
    pv = [b for b in out if b['cls'] == 'P']
    for a, b in zip([None] + pv[:-1], pv):
        b['bstart'] = (b['lab'] == 'gather2504' and a is not None and a['lab'] == 'slot22')
    for b in out:
        b.setdefault('bstart', False)
    return dict(bufs=out, tail=tail, start_gap=out[0]['gap'])


TEMPL = [make_template(i) for i in range(1, 7)]

if 'tmpl' in SECT:
    print('=== templates (leg 1, requests 2 to 7; enabler rule as in the header) ===')
    for i, t in enumerate(TEMPL):
        b = t['bufs']
        P = [x for x in b if x['cls'] == 'P']
        S = [x for x in b if x['cls'] == 'S']
        nb = sum(x['bstart'] for x in b)
        gP = sum(x['gap'] for x in P)
        gS = sum(x['gap'] for x in S)
        cross = sum(1 for k, x in enumerate(b) if x['en'] >= 0 and b[x['en']]['cls'] != x['cls'])
        big = sorted(((x['gap'], x['lab'], b[x['en']]['lab'] if x['en'] >= 0 else 'START') for x in b), reverse=True)[:3]
        print('req %d: %d prover + %d sealing buffers, %d block starts; prover work %.3f s, sealing work %.3f s; sum of gaps prover %.3f s, '
              'sealing %.3f s; cross-class enablers %d; first gap %.3f s, tail %.3f s; largest gaps %s'
              % (i + 1, len(P), len(S), nb, sum(x['work'] for x in P), sum(x['work'] for x in S), gP, gS, cross, t['start_gap'], t['tail'],
                 ', '.join('%.3f (%s after %s)' % g for g in big)))

# ---------------------------------------------------------------- simulation
RATES = {
    # work rate R(k) in solo-seconds per second with k buffers executing, from tick 34 section 3 (item 56 (c)), leg 2 and leg 5
    6: {1: 1.00, 2: 1.33, 3: 1.37, 4: 1.63},
    8: {1: 1.00, 2: 1.32, 3: 1.21, 4: 1.51},
}


def simulate(lanes, nreq, rates, hp=1.0, hs=1.0, ws=1.0, cap=None, stagger=0.3, seed=0, jitter=0.0, scale_p=1.0, hostp=1.0,
             seal_cpu=None, seal_cpu_frac=1.0, gate=None, rate_scale=1.0, extra_lat=0.0, seal_serial=0):
    """lanes x nreq requests.  hp: host stretch of prover gaps; hs: of sealing gaps, start gap and tail; ws: sealing work scale;
    scale_p: prover work scale (candidate iv); hostp: extra prover-gap scale (candidate iii);
    seal_cpu: if not None, sealing buffers are removed from the device and cost seal_cpu * (their solo time) of host time
              in the chain (candidate v), for a fraction seal_cpu_frac of sealing buffers (by index, the smallest solo times first);
    gate: None or ('blk', B, origin): the start of a block (prover gather2504 after slot22) is not earlier than origin + j*B/lanes + n*B
    for lane j's n-th block started since the run began."""
    rng = random.Random(seed)
    R = lambda k: rates[min(k, 4)] * rate_scale if k > 0 else 0.0
    order = list(range(lanes))
    rng.shuffle(order)
    heap = []
    cnt = [0]

    def push(t, typ, *a):
        cnt[0] += 1
        heapq.heappush(heap, (t, cnt[0], typ, a))

    st = {}  # (lane, req, idx) -> dict
    running = {}  # id -> [rem, key]
    waitq = []
    comps = []  # (time, lane)
    ivs_dev = []  # (gs, ge) all buffers
    inflight = collections.defaultdict(list)  # lane -> [(begin, done)] prover buffers
    lane_state = {}
    for l in range(lanes):
        lane_state[l] = dict(req=0, tmpl=None)

    # candidate v: which sealing buffers go to the host
    cpu_set = set()
    if seal_cpu is not None:
        # choose by solo time: the smallest fraction of buffers (keyed by (template, idx))
        allS = sorted(((b['work'], ti, k) for ti, t in enumerate(TEMPL) for k, b in enumerate(t['bufs']) if b['cls'] == 'S'))
        nsel = int(round(seal_cpu_frac * len(allS)))
        cpu_set = {(ti, k) for _, ti, k in allS[:nsel]}

    def start_request(l, t):
        ls = lane_state[l]
        ti = (order[l] + ls['req'] * 5 + seed) % 6
        T = TEMPL[ti]
        ls['tmpl'] = ti
        ls['t0'] = t
        ls['bufs'] = T['bufs']
        ls['n'] = len(T['bufs'])
        ls['ndone'] = 0
        ls['dep'] = collections.defaultdict(list)
        for k, b in enumerate(T['bufs']):
            ls['dep'][b['en']].append(k)
        for k in ls['dep'][-1]:
            sched_begin(l, ls['req'], k, t)

    def gapof(b):
        g = b['gap']
        if b['cls'] == 'P':
            g *= hp * hostp
        else:
            g *= hs
        if jitter > 0:
            g *= math.exp(rng.gauss(0, jitter) - jitter * jitter / 2)
        return g

    def sched_begin(l, req, k, tdone):
        ls = lane_state[l]
        b = ls['bufs'][k]
        t = tdone + (b['gap'] * hs if b['en'] == -1 else gapof(b))
        if gate is not None and gate[0] == 'blk' and b['bstart']:
            Bp = gate[1]
            nblk = ls.setdefault('blk', 0)
            tgrid = gate[2] + l * Bp / lanes + nblk * Bp
            t = max(t, tgrid)
            ls['blk'] = nblk + 1
        if (l, req, k) in st:
            return
        st[(l, req, k)] = dict(cls=b['cls'])
        if (ls['tmpl'], k) in cpu_set:
            # sealing product done on the host: occupies the chain for seal_cpu * solo time instead of the device
            push(t + seal_cpu * b['work'] + b['dl'], 'done', l, req, k)
            return
        push(t, 'commit', l, req, k)

    nextid = [0]

    def try_start(now):
        # waitq holds (l, req, k) in launch order.  seal_serial = n: at most n sealing buffers execute at once (the sealing
        # queue 99 is one queue shared by all lanes); 0 = no limit.
        i = 0
        while i < len(waitq) and (cap is None or len(running) < cap):
            key = waitq[i]
            l, req, k = key
            cls = st[key]['cls']
            if cls == 'S' and seal_serial and sum(1 for v in running.values() if st[v[1]]['cls'] == 'S') >= seal_serial:
                i += 1
                continue
            del waitq[i]
            b = lane_state[l]['bufs'][k]
            w = b['work'] * (ws if b['cls'] == 'S' else scale_p)
            nextid[0] += 1
            running[nextid[0]] = [w, key, now]
            st[key]['gs'] = now

    now = 0.0
    for l in range(lanes):
        lane_state[l]['t_first'] = l * stagger
        push(l * stagger, 'req', l)
    total = lanes * nreq
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
                l = a[0]
                start_request(l, now)
            elif typ == 'commit':
                l, req, kk = a
                b = lane_state[l]['bufs'][kk]
                st[(l, req, kk)]['beg'] = now
                push(now + b['lat'] + extra_lat, 'launch', l, req, kk)
            elif typ == 'launch':
                waitq.append(a)
                try_start(now)
                # record start time for those that began
                for v in running.values():
                    pass
            elif typ == 'done':
                l, req, kk = a
                ls = lane_state[l]
                b = ls['bufs'][kk]
                s = st[(l, req, kk)]
                s['dn'] = now
                if b['cls'] == 'P' and 'beg' in s:
                    inflight[l].append((s['beg'], now))
                ls['ndone'] += 1
                for k2 in ls['dep'].get(kk, []):
                    sched_begin(l, req, k2, now)
                if ls['ndone'] == ls['n']:
                    tailt = now + TEMPL[ls['tmpl']]['tail'] * hs
                    push(tailt, 'complete', l, req)
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
            now = tf
            fin = [i for i, v in running.items() if v[0] <= 1e-12]
            for i in fin:
                rem, key, t_s = running.pop(i)
                ivs_dev.append((t_s, now))
                l, req, kk = key
                b = lane_state[l]['bufs'][kk]
                push(now + b['dl'], 'done', l, req, kk)
            try_start(now)
        # gpu start times of newly started buffers are set in try_start via running[...][2]
    comps.sort()
    qs = [(v['gs'] - v['beg']) for (l, rq, k), v in st.items() if 'gs' in v and 'beg' in v and v['cls'] == 'P']
    simulate.last_q = 1e3 * sum(qs) / len(qs) * 18.5 if qs else float('nan')   # ms of queue time per block (leg 2: 51.9, leg 1: 12.2)
    return comps, ivs_dev, inflight


def stats(comps, ivs, inflight, lanes, N, T):
    t0, t1 = comps[N - 1][0], comps[N + T - 1][0]
    W = t1 - t0
    ev = []
    for a, b in ivs:
        a, b = max(a, t0), min(b, t1)
        if b > a:
            ev.append((a, 1))
            ev.append((b, -1))
    ev.sort()
    lev = collections.defaultdict(float)
    k = 0
    last = t0
    for t, d in ev:
        lev[k] += t - last
        last = t
        k += d
    lev[k] += t1 - last
    hi = sum(v for kk, v in lev.items() if kk >= 3) / W
    rate = T * 128 / W
    # in-flight variance ratio and none-in-flight share (1 ms sampling)
    step = 0.001
    ns = int(W / step)
    cnt = [0] * ns
    ps = []
    for l in range(lanes):
        iv = sorted((max(a, t0), min(b, t1)) for a, b in inflight[l] if min(b, t1) > max(a, t0))
        mer = []
        for a, b in iv:
            if mer and a <= mer[-1][1]:
                mer[-1][1] = max(mer[-1][1], b)
            else:
                mer.append([a, b])
        ps.append(sum(b - a for a, b in mer) / W)
        for a, b in mer:
            for i in range(int((a - t0) / step), min(ns, int((b - t0) / step) + 1)):
                cnt[i] += 1
    mean = sum(cnt) / ns
    var = sum((c - mean) ** 2 for c in cnt) / ns
    vind = sum(p * (1 - p) for p in ps)
    none = sum(1 for c in cnt if c == 0) / ns
    ind = math.prod(1 - p for p in ps)
    # work per busy second is not needed here; also request period per lane
    return dict(rate=rate, W=W, empty=lev[0] / W, hi=hi, none=none, vr=var / vind if vind > 0 else float('nan'), ind=ind,
                lev={kk: v / W for kk, v in sorted(lev.items())})


# measured (leg 2, leg 5): from the co-coordinator's table and tick 34
MEAS = {6: dict(rate=44.047, empty=0.227, hi=0.402, none=0.209, vr=2.66, N=6, T=48, nreq=9, hp=266 / 219.0),
        8: dict(rate=42.896, empty=0.260, hi=0.520, none=0.259, vr=4.67, N=8, T=48, nreq=7, hp=351 / 219.0)}


def fmt(s):
    return 'rate %.2f | empty %.1f%% | >=3 at once %.1f%% | none in flight %.1f%% (indep %.1f%%) | in-flight variance ratio %.2f' % (
        s['rate'], 100 * s['empty'], 100 * s['hi'], 100 * s['none'], 100 * s['ind'], s['vr'])


def run(lanes, seeds=3, **kw):
    M = MEAS[lanes]
    out = []
    for sd in range(seeds):
        comps, ivs, inf = simulate(lanes, M['nreq'], RATES[lanes], seed=sd, **kw)
        out.append(stats(comps, ivs, inf, lanes, M['N'], M['T']))
    keys = ['rate', 'empty', 'hi', 'none', 'vr', 'ind']
    m = {k: sum(o[k] for o in out) / len(out) for k in keys}
    m['spread'] = (min(o['rate'] for o in out), max(o['rate'] for o in out))
    return m


def line(tag, m, ref=None):
    s = '%-58s %s [rate range %.2f to %.2f]' % (tag, fmt(m), m['spread'][0], m['spread'][1])
    if ref:
        s += ' | rate x%.3f' % (m['rate'] / ref['rate'])
    print(s)


if 'base' in SECT:
    print('\n=== base replay against the measured legs (3 seeds = 3 template assignments; start stagger 0.3 s) ===')
    for lanes in (6, 8):
        M = MEAS[lanes]
        print('measured, %d lanes: rate %.2f | empty %.1f%% | >=3 at once %.1f%% | none in flight %.1f%% | variance ratio %.2f' % (
            lanes, M['rate'], 100 * M['empty'], 100 * M['hi'], 100 * M['none'], M['vr']))
        for ws in (1.0, 0.75):
            m = run(lanes, hp=M['hp'], hs=M['hp'], ws=ws)
            line('replay h=%.3f (both), sealing work x%.2f' % (M['hp'], ws), m)
        m = run(lanes, hp=M['hp'], hs=M['hp'], ws=0.75, jitter=0.3)
        line('replay h=%.3f, sealing x0.75, gap noise sigma 0.3' % M['hp'], m)

if 'sens' in SECT:
    print('\n=== sensitivity of the six-lane replay (ws 0.75) ===')
    M = MEAS[6]
    for hp, hs in ((1.0, 1.0), (1.215, 1.0), (1.215, 1.215), (1.215, 1.6), (1.4, 1.4), (1.6, 1.6)):
        line('host stretch prover %.3f, sealing/boundary %.3f' % (hp, hs), run(6, hp=hp, hs=hs, ws=0.75))
    for st_ in (0.0, 0.3):
        line('stagger %.1f s' % st_, run(6, hp=M['hp'], hs=M['hp'], ws=0.75, stagger=st_))
    for el in (0.002, 0.004):
        line('extra launch latency %.0f ms (leg 2 has +2.1 ms mean over leg 1)' % (el * 1e3), run(6, hp=M['hp'], hs=M['hp'], ws=0.75, extra_lat=el))
    for rs in (0.9, 1.1):
        line('device rate R(k) x%.1f' % rs, run(6, hp=M['hp'], hs=M['hp'], ws=0.75, rate_scale=rs))

if 'diag' in SECT:
    print('\n=== diag: levels (buffers executing at once) in leg 2 against the replay, and queue time per block ===')
    L2 = legs[1]
    rows2 = load(L2)
    cc = sorted(x['t_abs'] for x in L2['completions'])
    a0, a1 = cc[L2['N'] - 1], cc[L2['N'] + L2['timed'] - 1]
    ev = []
    for r in rows2:
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
    W = a1 - a0
    print('leg 2 measured level shares: ' + ', '.join('%d: %.1f%%' % (kk, 100 * v / W) for kk, v in sorted(lev.items())) + '; max level %d' % max(lev))
    M = MEAS[6]
    for tag, kw in (('base', {}), ('sealing queue serial', dict(seal_serial=1)), ('sealing 2 at once', dict(seal_serial=2)), ('cap 4', dict(cap=4)), ('cap 5', dict(cap=5)), ('cap 6', dict(cap=6)), ('cap 5, extra 2 ms', dict(cap=5, extra_lat=0.002))):
        comps, ivs, inf = simulate(6, 9, RATES[6], seed=0, hp=M['hp'], hs=M['hp'], ws=0.75, **kw)
        q = simulate.last_q
        s_ = stats(comps, ivs, inf, 6, 6, 48)
        print('%-20s q per block %.1f ms | %s | levels: %s' % (tag, q, fmt(s_), ', '.join('%d: %.1f%%' % (kk, 100 * v) for kk, v in s_['lev'].items())))

if 'cand' in SECT:
    print('\n=== candidates (six lanes; base = replay h=%.3f, sealing x0.75; compare with the base line, not with the measured leg) ===' % MEAS[6]['hp'])
    M = MEAS[6]
    kw = dict(hp=M['hp'], hs=M['hp'], ws=0.75)
    base = run(6, **kw)
    line('base', base)
    # (i) held phase offsets
    comps, ivs, inf = simulate(6, 9, RATES[6], seed=0, **kw)
    per = (comps[53][0] - comps[5][0]) / 48 * 6   # lane period = window / requests per lane (8 per lane in 48 completions)
    print('  (base lane period from the replay: %.2f s)' % per)
    # block gate: a block start is not earlier than a grid of period B, lane j shifted by j*B/6; B = lane period / 26 times f
    for f in (1.0, 1.05, 1.15):
        B = per / 26 * f
        m = run(6, gate=('blk', B, 0.0), **kw)
        line('(i) block starts held on a grid of %.0f ms (period x%.2f), lanes 1/6 apart' % (B * 1e3, f), m, base)
    # (ii) caps
    for cp in (2, 3, 4):
        line('(ii) at most %d buffers executing at once (R(k) of the rate table)' % cp, run(6, cap=cp, **kw), base)
    # (iii) 10% less host time per block
    line('(iii) prover host gaps x0.9', run(6, hostp=0.9, **kw), base)
    # (iv) 10% less device work per block
    line('(iv) prover device work x0.9', run(6, scale_p=0.9, **kw), base)
    # (v) sealing products off the device at a host cost r times their device time
    for frac in (1.0, 0.5):
        for r in (0.0, 0.5, 1.0, 2.0, 4.0):
            line('(v) %d%% of sealing products on the host, host time %.1f x device time' % (100 * frac, r),
                 run(6, seal_cpu=r, seal_cpu_frac=frac, **kw), base)
