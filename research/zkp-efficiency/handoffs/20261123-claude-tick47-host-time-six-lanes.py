#!/usr/bin/env python3
"""Tick 47 (queue item 77): what a lane's host time per block consists of at six lanes.  Standard library only, reads retained traces.
Usage:  python3 -I -B this.py <repo root>  [a|b|c]      (default: all sections)
Datasets (all W16R2 Shieldstral app profile, request thread = thread with > 1000 buffers; definitions are tick 38's, re-implemented here and checked against
tick 38's published periods):
  lt1  = results/zk60_lane_threads_20261122  lt_trace leg 3 (1 lane x 5 threads, fused RS + sparse fold on, 8 timed requests)
  lt6  = same, leg 1 (6 lanes x 5 threads)
  trA  = results/zk60_bundle_app_20261123  bn_trace leg 1 (arm A: base binary B0, frs1 sf1; 6 x 5)
  trC  = same, leg 2 (arm C: B1 + open-fast + reg8; 6 x 5)
  old1 = results/zk60_lanes_trace_20261121  tr_leg1 (1 lane x 5; OLDER binary, no fused RS / sparse fold)
  old6 = same, tr_main leg 2 (6 x 5, A36 off; same older binary)
A block runs from the begin of one A commit (rows=2504) to the begin of the next on the same thread; kept when its first A commit begins inside
[completion N, completion N+timed].  Every buffer p of a block (all but the closing A commit) is charged: encode (com-beg), queue (gs-com), exec (ge-gs),
wait (dn-ge) and the GAP to the next buffer q (q.beg - p.dn).  Host time of the block = encode + gap (README's 'host time' = wall - e - q - w).

PRE-REGISTERED LINES (written before the first run of this script)
 (a) arm A's device execution per kind agrees with tick 40's six-lane column (as given in the handoff) within 10% for each of the ten named kinds and for
     the sum (217.883 ms): pass; any named kind outside 10%: report it and do not use tick 40's column for it.
 (b) a gap key 'grows' from one lane to six when its ms per block at six lanes exceeds one lane's by at least 1.0 ms in BOTH pairs (lt1->lt6 and old1->old6).
     Pass of (b): tables with each figure printed; the keys that grow and their sum; the share of the one-to-six host growth they hold.
 (c) 'six lanes x five threads plus the sealing pool can explain a stretch of host work' is supported if, at six lanes, within one gap group the mean gap
     of gaps that start while at least 3 other lanes are in a host state is at least 1.25 x the mean of gaps that start while no other lane is in a host state,
     in at least two of the three six-lane traces (lt6, trA, old6); not supported if under 1.10 x in two of three; otherwise undecided.
     (A lane's 'host state' = its encode intervals and its gaps; the trace has no CPU-time column, so this counts lanes in host code, not runnable threads.)

 SUPPLEMENT 'd' (NOT pre-registered; added after the first run showed that the literal line (c) is met for G5 only, with 0-bin counts of 10 to 32 gaps; line fixed
     BEFORE this section was run): a time-shift control.  For each gap, the number of OTHER lanes in a host state is taken at the gap midpoint (d = 0) and at
     midpoint + d for d = +-0.1, +-0.2, +-0.3 s (not multiples of the 0.5 s block period).  Bins: low = at most 1 other lane, high = at least 4.  If the d = 0 ratio
     (mean gap high / mean gap low) exceeds every shifted ratio by at least 0.10 for G5 in at least two of the three traces, the association is with the lanes'
     SIMULTANEOUS state (contention is possible); if the shifted ratios are within 0.05 of the d = 0 ratio, it is common-mode (slow stretches of the run), not contention.

 SUPPLEMENT 'e' (NOT pre-registered; line fixed BEFORE it was run; added because the control of 'd' left G2 as the only group whose simultaneous-state ratio
     exceeds its shifted ratios): is G2's stretch (+8 ms from one lane to six, in both pairs) contention between lanes that are in G2 at the same moment (the disk sink:
     SHA-256, write, fsync, rename, ticks 31 and 32)?  For each G2 gap, count the OTHER lanes whose own G2 gap contains the midpoint (0, 1, 2 or more).
     Sink contention is supported if, in at least two of the three six-lane traces, the mean G2 gap with 2 or more other lanes in G2 exceeds the mean with none by at
     least 4 ms AND the same difference computed at midpoint +-0.2 and +-0.3 s (the control) is under 2 ms in absolute value; not supported if under 2 ms at d = 0 in
     two of three.
"""
import bisect
import collections
import json
import lzma
import os
import re
import statistics as st
import sys

ROOT = sys.argv[1].rstrip('/')
SECT = set(sys.argv[2:]) or {'a', 'b', 'c'}
LT = ROOT + '/results/zk60_lane_threads_20261122/raw'
BN = ROOT + '/results/zk60_bundle_app_20261123/raw'
TR = ROOT + '/results/zk60_lanes_trace_20261121/raw'


def load(raw, prefix, pid):
    f = '%s/traces/%s.%d.tsv.xz' % (raw, os.path.basename(prefix), pid)
    rows = []
    for i, line in enumerate(lzma.open(f, 'rt')):
        p = line.rstrip('\n').split('\t')
        if i == 0 or len(p) != 9:
            continue
        rows.append(dict(tag=p[0], det=p[1], th=int(p[2]), q=int(p[3]), beg=float(p[4]), com=float(p[5]), gs=float(p[6]), ge=float(p[7]), dn=float(p[8])))
    return rows


def key(r):
    d, t = r['det'], r['tag']
    if t == 'commit':
        return 'commit ' + d.split(' log_n')[0]
    if t == 'gather':
        return 'gather ' + d.split(' nn')[0]
    if t == 'spfold':
        return 'spfold ' + d.split(' active')[0]
    if t == 'batch':
        m = re.match(r'slot (\d+)', d)
        return 'slot%02d' % int(m.group(1)) if m else 'batch ' + d.split(' (')[0]
    return t


def group(k):
    a, b = k
    if b.startswith('spfold') or a.startswith('spfold') or (a == 'slot22' and b.startswith('gather')) or (a.startswith('gather') and b.startswith('gather')):
        return 'G1 openings tail'
    if (a, b) == ('gather rows=38', 'commit rows=38'):
        return 'G2 gather 38 -> boundary commit'
    if (a, b) == ('commit rows=38', 'commit rows=2504'):
        return 'G3 boundary commit -> A commit'
    if (a, b) == ('commit rows=2504', 'commit rows=2606'):
        return 'G4 A commit -> H commit'
    if a.startswith('slot') and b.startswith('slot') and int(a[4:]) < 14 and int(b[4:]) == 14:
        return 'G5 slots 5-13 -> slot 14'
    if a.startswith('slot') or b.startswith('slot'):
        return 'G6 other slot gaps'
    return 'G7 other'


def requests(rows):
    by = collections.defaultdict(list)
    for r in rows:
        by[r['th']].append(r)
    main = sorted(t for t, v in by.items() if len(v) > 1000)
    reqs = []
    for t in main:
        v = sorted((r for r in by[t] if not (r['tag'] == 'wprod' and 't=65' in r['det'])), key=lambda r: r['beg'])
        starts = [i for i, r in enumerate(v) if r['tag'] == 'wprod' and (i == 0 or v[i - 1]['tag'] != 'wprod')]
        starts.append(len(v))
        for a, b in zip(starts, starts[1:]):
            reqs.append((t, v[a:b]))
    return main, reqs, by


def cnt(a, x):
    return bisect.bisect_right(a, x)


class Host:
    """host state of request threads (encode + gaps) and of sealing threads, for concurrency queries"""

    def __init__(self, rows):
        iv = []
        by = collections.defaultdict(list)
        for r in rows:
            by[r['th']].append(r)
        self.seal_threads = sorted(set(r['th'] for r in rows if r['q'] == 99))
        for t, v in by.items():
            v.sort(key=lambda r: r['beg'])
            req = len(v) > 1000
            for i, r in enumerate(v):
                iv.append((r['beg'], r['com'], 'R' if req else 'S'))
                if i + 1 < len(v):
                    g = v[i + 1]['beg'] - r['dn']
                    if g > 0 and g < (1.0 if req else 0.1):
                        iv.append((r['dn'], v[i + 1]['beg'], 'R' if req else 'S'))
        self.own = {}
        for t, v in by.items():
            if len(v) > 1000:
                o = []
                for i, r in enumerate(v):
                    o.append((r['beg'], r['com']))
                    if i + 1 < len(v):
                        g = v[i + 1]['beg'] - r['dn']
                        if 0 < g < 1.0:
                            o.append((r['dn'], v[i + 1]['beg']))
                self.own[t] = (sorted(a for a, b in o), sorted(b for a, b in o))
        self.s = {k: sorted(a for a, b, c in iv if c == k) for k in 'RS'}
        self.e = {k: sorted(b for a, b, c in iv if c == k) for k in 'RS'}
        ex = [(r['gs'], r['ge']) for r in rows if r['q'] != 99 and r['ge'] >= r['gs']]
        self.xs = sorted(a for a, b in ex)
        self.xe = sorted(b for a, b in ex)
        sx = [(r['gs'], r['ge']) for r in rows if r['q'] == 99 and r['ge'] >= r['gs']]
        self.ss = sorted(a for a, b in sx)
        self.se = sorted(b for a, b in sx)

    def lanes_host(self, t):
        return cnt(self.s['R'], t) - cnt(self.e['R'], t)

    def others_host(self, t, th):
        a, b = self.own[th]
        return self.lanes_host(t) - (cnt(a, t) - cnt(b, t))

    def seal_host(self, t):
        return cnt(self.s['S'], t) - cnt(self.e['S'], t)

    def prover_exec(self, t):
        return cnt(self.xs, t) - cnt(self.xe, t)

    def seal_exec(self, t):
        return cnt(self.ss, t) - cnt(self.se, t)


def analyse(rows, c_sorted, N, T, want_conc):
    lo, hi = c_sorted[N - 1], c_sorted[N + T - 1]
    main, reqs, by = requests(rows)
    H = Host(rows) if want_conc else None
    nb = 0
    ph = collections.defaultdict(collections.Counter)
    keyg = collections.defaultdict(lambda: [0.0, 0])
    keyx = collections.defaultdict(float)
    kindx = collections.defaultdict(float)
    kindn = collections.defaultdict(int)
    per = []
    tot = collections.Counter()
    conc = collections.defaultdict(list)       # group -> list of (gap, other lanes host, other lanes exec-prover, seal host)
    for t, v in reqs:
        A = [i for i, r in enumerate(v) if r['tag'] == 'commit' and 'rows=2504' in r['det']]
        for i0, i1 in zip(A, A[1:]):
            if not (lo <= v[i0]['beg'] <= hi):
                continue
            seg = v[i0:i1 + 1]
            nb += 1
            per.append(seg[-1]['beg'] - seg[0]['beg'])
            for p, q in zip(seg, seg[1:]):
                k = (key(p), key(q))
                g = group(k)
                c_ = ph[g]
                gap = q['beg'] - p['dn']
                c_['encode'] += p['com'] - p['beg']
                c_['queue'] += p['gs'] - p['com']
                c_['exec'] += p['ge'] - p['gs']
                c_['wait'] += p['dn'] - p['ge']
                c_['gap'] += gap
                keyg[k][0] += gap
                keyg[k][1] += 1
                keyx[k] += p['ge'] - p['gs']
                kindx[key(p)] += p['ge'] - p['gs']
                kindn[key(p)] += 1
                for f, x in (('encode', p['com'] - p['beg']), ('queue', p['gs'] - p['com']), ('exec', p['ge'] - p['gs']), ('wait', p['dn'] - p['ge']), ('gap', gap)):
                    tot[f] += x
                if H is not None and gap > 0:
                    mid = p['dn'] + gap / 2
                    conc[g].append((gap, H.lanes_host(mid) - 1, H.prover_exec(mid), H.seal_host(mid), H.seal_exec(mid), t, mid))
    out = dict(nb=nb, period=sum(per) / nb * 1e3, sd=st.pstdev(per) * 1e3, main=main, nseal=len(H.seal_threads) if H else None,
               ph={g: {k: (v / nb * 1e3) for k, v in c.items()} for g, c in ph.items()},
               keyg={k: (v[0] / nb * 1e3, v[1] / nb) for k, v in keyg.items()}, keyx={k: v / nb * 1e3 for k, v in keyx.items()},
               kindx={k: v / nb * 1e3 for k, v in kindx.items()}, tot={k: v / nb * 1e3 for k, v in tot.items()}, conc=conc, H=H, lo=lo, hi=hi)
    for g in out['ph']:
        c = out['ph'][g]
        c['total'] = c['encode'] + c['queue'] + c['exec'] + c['wait'] + c['gap']
    return out


def completions(path, idx):
    d = json.load(open(path))
    L = d['legs'][idx]
    return L, sorted(x['t_abs'] for x in L['completions'])


DS = {}
specs = [
    ('lt1', LT, LT + '/lt_trace/t2_results.json', 2, True),
    ('lt6', LT, LT + '/lt_trace/t2_results.json', 0, True),
    ('trA', BN, BN + '/bn_trace/t2_results.json', 0, True),
    ('trC', BN, BN + '/bn_trace/t2_results.json', 1, True),
    ('old1', TR, TR + '/tr_leg1/t2_results.json', 0, True),
    ('old6', TR, TR + '/tr_main/t2_results.json', 0, True),
]
LEGS = {}
for nm, raw, js, idx, wc in specs:
    L, c = completions(js, idx)
    rows = load(raw, L['trace_prefix'], L['server_pid'])
    DS[nm] = analyse(rows, c, L['N'], L['timed'], wc and L['lanes'] > 1)
    LEGS[nm] = L
    r = DS[nm]
    s = sum(v['total'] for v in r['ph'].values())
    print('== %-4s lanes %d x %d threads, N %d timed %d, %d records, %d request threads, %d blocks kept; period %.2f ms (sd %.1f), sum of phases %.2f (diff %.4f)' % (
        nm, L['lanes'], L['threads'], L['N'], L['timed'], len(rows), len(r['main']), r['nb'], r['period'], r['sd'], s, s - r['period']))
    print('      e %.1f q %.1f w %.1f  encode %.1f gap %.1f  host (encode+gap) %.1f ms per block of the 25-block loop; traced rate %.2f' % (
        r['tot']['exec'], r['tot']['queue'], r['tot']['wait'], r['tot']['encode'], r['tot']['gap'], r['tot']['encode'] + r['tot']['gap'], L['rate']))
print('(tick 38 published: lt6 period 504.96, lt1 302.31 -- the first two lines above are the re-implementation check)')

TICK40 = {'slot18': 52.71, 'slot14': 33.07, 'commit rows=2606': 17.34, 'commit rows=2504': 16.64, 'slot17': 25.19, 'slot15': 14.08, 'spfold rows=2504': 6.07,
          'slot19': 10.73, 'slot16': 8.43, 'slot00': 8.46}
TICK40_ALL, TICK40_OTHER = 217.883, 25.16

if 'a' in SECT:
    print('\n=== (a) device execution per kind, ms per block: arm A against tick 40 six-lane column (as given) ===')
    A = DS['trA']['kindx']
    named = 0.0
    bad = []
    print('%-22s %9s %9s %7s %9s %9s' % ('kind', 'tick 40', 'arm A', 'ratio', 'arm C', 'lt6'))
    for k, v in TICK40.items():
        a = A.get(k, 0.0)
        named += a
        print('%-22s %9.2f %9.2f %7.3f %9.2f %9.2f' % (k, v, a, a / v, DS['trC']['kindx'].get(k, 0), DS['lt6']['kindx'].get(k, 0)))
        if abs(a / v - 1) > 0.10:
            bad.append(k)
    other = sum(A.values()) - named
    print('%-22s %9.2f %9.2f %7.3f' % ('all others', TICK40_OTHER, other, other / TICK40_OTHER))
    print('%-22s %9.3f %9.3f %7.3f' % ('SUM', TICK40_ALL, sum(A.values()), sum(A.values()) / TICK40_ALL))
    print('named kinds outside 10%%: %s; sum within 10%%: %s' % (bad or 'none', abs(sum(A.values()) / TICK40_ALL - 1) <= 0.10))
    # README reconciliation for A and C: wall = mean prove_s / 26, host = wall - e - q - w
    for nm, bj in (('trA', 0), ('trC', 1)):
        L = LEGS[nm]
        pr = [x['prove_s'] for x in L['completions'] if L['N'] < x['n'] <= L['N'] + L['timed'] and 'prove_s' in x]
        wall = st.mean(pr) / 26 * 1e3
        r = DS[nm]
        print('%s: mean prove call of the %d timed requests %.3f s -> wall %.1f ms per block (26 blocks); e %.1f q %.1f w %.1f -> README-style host %.1f ms; '
              'loop host (encode+gap, 25 blocks) %.1f ms; difference %.1f ms = head and last block per 26: %.1f ms' % (
                  nm, len(pr), st.mean(pr), wall, r['tot']['exec'], r['tot']['queue'], r['tot']['wait'], wall - r['tot']['exec'] - r['tot']['queue'] - r['tot']['wait'],
                  r['tot']['encode'] + r['tot']['gap'], wall - r['tot']['exec'] - r['tot']['queue'] - r['tot']['wait'] - r['tot']['encode'] - r['tot']['gap'],
                  wall - r['period']))

if 'b' in SECT:
    names = ['lt1', 'lt6', 'old1', 'old6', 'trA', 'trC']
    print('\n=== (b1) phase table, ms per block (host = encode + gap) ===')
    for nm in names:
        r = DS[nm]
        print('--- %s period %.1f' % (nm, r['period']))
        for g in sorted(r['ph']):
            c = r['ph'][g]
            print('  %-34s enc %5.1f q %5.1f ex %6.1f wt %4.1f gap %6.1f | host %6.1f total %6.1f' % (g, c['encode'], c['queue'], c['exec'], c['wait'], c['gap'], c['encode'] + c['gap'], c['total']))
        print('  %-34s enc %5.1f q %5.1f ex %6.1f wt %4.1f gap %6.1f | host %6.1f' % ('all', r['tot']['encode'], r['tot']['queue'], r['tot']['exec'], r['tot']['wait'], r['tot']['gap'], r['tot']['encode'] + r['tot']['gap']))
    print('\n=== (b2) growth of host time (encode+gap) from one lane to six, by phase: pair lt (same config as arm A) and pair old (older binary) ===')
    print('%-34s %8s %8s %7s | %8s %8s %7s' % ('phase', 'lt1', 'lt6', 'diff', 'old1', 'old6', 'diff'))
    gs = sorted(set(DS['lt6']['ph']) | set(DS['old6']['ph']))
    hs = lambda nm, g: DS[nm]['ph'].get(g, {}).get('encode', 0) + DS[nm]['ph'].get(g, {}).get('gap', 0)
    for g in gs:
        print('%-34s %8.1f %8.1f %+7.1f | %8.1f %8.1f %+7.1f' % (g, hs('lt1', g), hs('lt6', g), hs('lt6', g) - hs('lt1', g), hs('old1', g), hs('old6', g), hs('old6', g) - hs('old1', g)))
    tot = lambda nm: DS[nm]['tot']['encode'] + DS[nm]['tot']['gap']
    print('%-34s %8.1f %8.1f %+7.1f | %8.1f %8.1f %+7.1f' % ('all', tot('lt1'), tot('lt6'), tot('lt6') - tot('lt1'), tot('old1'), tot('old6'), tot('old6') - tot('old1')))
    print('\n=== (b3) per transition key: gap ms per block (count per block), one lane -> six lanes, both pairs; all keys with |diff| >= 0.3 ms in either pair ===')
    ks = set()
    for nm in names:
        ks |= set(DS[nm]['keyg'])
    rows_ = []
    for k in ks:
        g = lambda nm: DS[nm]['keyg'].get(k, (0.0, 0.0))
        rows_.append((g('lt6')[0] - g('lt1')[0], g('old6')[0] - g('old1')[0], k))
    rows_.sort(key=lambda x: -(x[0] + x[1]))
    print('%7s %7s | %7s %7s %5s | %7s %7s | %7s %7s | %s' % ('d_lt', 'd_old', 'lt1', 'lt6', 'n/blk', 'old1', 'old6', 'trA', 'trC', 'transition (group)'))
    grow = []
    for d1, d2, k in rows_:
        if abs(d1) < 0.3 and abs(d2) < 0.3:
            continue
        g = lambda nm: DS[nm]['keyg'].get(k, (0.0, 0.0))
        flag = ' GROWS' if (d1 >= 1.0 and d2 >= 1.0) else ''
        if flag:
            grow.append((d1, d2, k))
        print('%+7.2f %+7.2f | %7.2f %7.2f %5.2f | %7.2f %7.2f | %7.2f %7.2f | %s -> %s (%s)%s' % (d1, d2, g('lt1')[0], g('lt6')[0], g('lt6')[1], g('old1')[0], g('old6')[0], g('trA')[0], g('trC')[0], k[0], k[1], group(k)[:2], flag))
    s1, s2 = sum(x[0] for x in grow), sum(x[1] for x in grow)
    print('keys that grow by >= 1.0 ms in both pairs: %d; their growth sums to %.1f ms (lt pair) and %.1f ms (old pair); host growth of the pair %.1f and %.1f ms; share %.0f%% / %.0f%%' % (
        len(grow), s1, s2, tot('lt6') - tot('lt1'), tot('old6') - tot('old1'), 100 * s1 / (tot('lt6') - tot('lt1')), 100 * s2 / (tot('old6') - tot('old1'))))
    print('sum of positive per-key growth, lt pair: %.1f; negative: %.1f' % (sum(x[0] for x in rows_ if x[0] > 0), sum(x[0] for x in rows_ if x[0] < 0)))
    print('\n=== (b4) the same, by what stands on either side: tag-kinds of the buffer before the gap (all gaps after that kind), ms per block ===')
    kk = collections.defaultdict(lambda: collections.defaultdict(float))
    for nm in names:
        for (a, b), (ms, n) in DS[nm]['keyg'].items():
            kk[a][nm] += ms
    items = sorted(kk.items(), key=lambda kv: -(kv[1]['lt6'] - kv[1]['lt1']))
    print('%-22s %7s %7s %7s | %7s %7s %7s | %7s %7s' % ('buffer before the gap', 'lt1', 'lt6', 'diff', 'old1', 'old6', 'diff', 'trA', 'trC'))
    for a, d in items[:14]:
        print('%-22s %7.1f %7.1f %+7.1f | %7.1f %7.1f %+7.1f | %7.1f %7.1f' % (a, d['lt1'], d['lt6'], d['lt6'] - d['lt1'], d['old1'], d['old6'], d['old6'] - d['old1'], d['trA'], d['trC']))
    print('\n=== (b5) device execution of the same buffers (the buffer before the gap), ms per block, for the stretch comparison with tick 42 ===')
    ke = collections.defaultdict(lambda: collections.defaultdict(float))
    for nm in names:
        for (a, b), x in DS[nm]['keyx'].items():
            ke[a][nm] += x
    for a, d in sorted(ke.items(), key=lambda kv: -kv[1]['lt6'])[:10]:
        print('%-22s lt1 %6.2f lt6 %6.2f x%.2f | old1 %6.2f old6 %6.2f x%.2f' % (a, d['lt1'], d['lt6'], d['lt6'] / d['lt1'] if d['lt1'] else float('nan'), d['old1'], d['old6'], d['old6'] / d['old1'] if d['old1'] else float('nan')))

if 'c' in SECT:
    print('\n=== (c) cores and concurrency ===')
    print('machine (sysctl, read earlier in this tick): 32 logical CPUs = 24 performance + 8 efficiency (hw.perflevel0 24, hw.perflevel1 8; physical = logical)')
    for nm in ('lt6', 'trA', 'old6'):
        r = DS[nm]
        L = LEGS[nm]
        print('%s: %d lanes x %d threads = %d prover pool threads; request threads in trace %d; sealing threads (queue 99) in trace %d' % (nm, L['lanes'], L['threads'], L['lanes'] * L['threads'], len(r['main']), r['nseal']))
        H = r['H']
        # time-weighted distribution of lanes in a host state over the kept window
        t0, t1 = r['lo'], r['hi']
        ev = sorted(set(H.s['R'] + H.e['R']) | {t0, t1})
        ev = [t for t in ev if t0 <= t <= t1]
        dist = collections.Counter()
        sealdist = collections.Counter()
        for a, b in zip(ev, ev[1:]):
            m = (a + b) / 2
            dist[H.lanes_host(m)] += b - a
            sealdist[min(H.seal_host(m), 99)] += b - a
        span = t1 - t0
        mean_lanes = sum(k * v for k, v in dist.items()) / span
        print('   time share with k lanes in a host state (encode or gap), k = 0..6: ' + ' '.join('%d:%.1f%%' % (k, 100 * dist.get(k, 0) / span) for k in range(0, 7)) + '  mean %.2f' % mean_lanes)
        ms = sum(k * v for k, v in sealdist.items()) / span
        print('   mean sealing threads in a host state (buffer encode or inter-buffer gap < 0.1 s; ASSUMED active): %.2f of %d' % (ms, r['nseal']))
        # demand bound: lanes in host x threads per lane (upper) / x1 (lower), plus sealing threads
        up = lo_ = over24 = over32 = 0.0
        thr = L['threads']
        for a, b in zip(ev, ev[1:]):
            m = (a + b) / 2
            k = H.lanes_host(m)
            s_ = H.seal_host(m)
            low, hi_ = k + s_, k * thr + s_
            up += hi_ * (b - a)
            lo_ += low * (b - a)
            over24 += (b - a) if hi_ > 24 else 0
            over32 += (b - a) if hi_ > 32 else 0
        print('   thread demand in host code, DERIVED: lower bound (1 thread per lane) mean %.1f; upper bound (all %d pool threads of every lane in host code) mean %.1f; share of time the upper bound exceeds 24 / 32: %.0f%% / %.0f%%' % (
            lo_ / span, thr, up / span, 100 * over24 / span, 100 * over32 / span))
        # concurrency test
        print('   mean gap (ms) by group, by the number of OTHER lanes in a host state at the gap midpoint (n in brackets): 0 | 1-2 | 3+ ; ratio 3+ over 0')
        res = {}
        for g in sorted(r['conc']):
            bins = {'0': [], '12': [], '3+': []}
            for gap, hl, pe, sh, se, _t, _m in r['conc'][g]:
                bins['0' if hl == 0 else ('12' if hl <= 2 else '3+')].append(gap * 1e3)
            m = {k: (st.mean(v) if v else float('nan')) for k, v in bins.items()}
            res[g] = (m, {k: len(v) for k, v in bins.items()})
            print('     %-34s %6.2f [%5d] | %6.2f [%5d] | %6.2f [%5d]  ratio %.2f' % (g, m['0'], len(bins['0']), m['12'], len(bins['12']), m['3+'], len(bins['3+']), m['3+'] / m['0'] if m['0'] == m['0'] and m['0'] > 0 else float('nan')))
        print('   mean gap (ms) by group, by number of prover buffers executing on the device (other lanes) at the midpoint: 0 | 1-2 | 3+')
        for g in sorted(r['conc']):
            bins = {'0': [], '12': [], '3+': []}
            for gap, hl, pe, sh, se, _t, _m in r['conc'][g]:
                bins['0' if pe == 0 else ('12' if pe <= 2 else '3+')].append(gap * 1e3)
            m = {k: (st.mean(v) if v else float('nan')) for k, v in bins.items()}
            print('     %-34s %6.2f [%5d] | %6.2f [%5d] | %6.2f [%5d]  ratio %.2f' % (g, m['0'], len(bins['0']), m['12'], len(bins['12']), m['3+'], len(bins['3+']), m['3+'] / m['0'] if m['0'] == m['0'] and m['0'] > 0 else float('nan')))
        print('   mean gap (ms) by group, by sealing threads in a host state at the midpoint: <=5 | 6-15 | 16+ (ASSUMED states)')
        for g in sorted(r['conc']):
            bins = {'<=5': [], '6-15': [], '16+': []}
            for gap, hl, pe, sh, se, _t, _m in r['conc'][g]:
                bins['<=5' if sh <= 5 else ('6-15' if sh <= 15 else '16+')].append(gap * 1e3)
            m = {k: (st.mean(v) if v else float('nan')) for k, v in bins.items()}
            print('     %-34s %6.2f [%5d] | %6.2f [%5d] | %6.2f [%5d]' % (g, m['<=5'], len(bins['<=5']), m['6-15'], len(bins['6-15']), m['16+'], len(bins['16+'])))
    print('\n--- (c) verdict inputs: ratio of mean gap with >= 3 other lanes in host over none, by group and trace ---')
    for g in sorted(DS['lt6']['conc']):
        out = []
        for nm in ('lt6', 'trA', 'old6'):
            v0 = [x[0] for x in DS[nm]['conc'][g] if x[1] == 0]
            v3 = [x[0] for x in DS[nm]['conc'][g] if x[1] >= 3]
            out.append('%s %.2f (n %d/%d)' % (nm, (st.mean(v3) / st.mean(v0)) if v0 and v3 else float('nan'), len(v0), len(v3)))
        print('  %-34s %s' % (g, '   '.join(out)))


if 'd' in SECT:
    print('\n=== (d) time-shift control (supplement, line fixed before the run): ratio of mean gap, >= 4 other lanes in host over <= 1, at shift d from the gap midpoint ===')
    SH = (0.0, -0.3, -0.2, -0.1, 0.1, 0.2, 0.3)
    for g in ('G2 gather 38 -> boundary commit', 'G3 boundary commit -> A commit', 'G4 A commit -> H commit', 'G5 slots 5-13 -> slot 14', 'G6 other slot gaps'):
        for nm in ('lt6', 'trA', 'old6'):
            H = DS[nm]['H']
            out = []
            for d in SH:
                lowv, highv = [], []
                for gap, hl, pe, sh, se, th, mid in DS[nm]['conc'][g]:
                    o = H.others_host(mid + d, th)
                    if o <= 1:
                        lowv.append(gap)
                    elif o >= 4:
                        highv.append(gap)
                out.append((d, (st.mean(highv) / st.mean(lowv)) if lowv and highv else float('nan'), len(lowv), len(highv)))
            print('  %-34s %-4s ' % (g[:34], nm) + '  '.join('d=%+.1f: %.3f (%d/%d)' % x for x in out))


if 'e' in SECT:
    print('\n=== (e) G2 gaps against the number of other lanes in G2 at the same moment (supplement, line fixed before the run) ===')
    G2 = 'G2 gather 38 -> boundary commit'
    for nm in ('lt6', 'trA', 'old6'):
        r = DS[nm]
        iv = collections.defaultdict(list)
        for gap, hl, pe, sh, se, th, mid in r['conc'][G2]:
            iv[th].append((mid - gap / 2, mid + gap / 2))
        for th in iv:
            iv[th].sort()
        starts = {th: [a for a, b in v] for th, v in iv.items()}

        def others_in_g2(t, th):
            n = 0
            for t2, v in iv.items():
                if t2 == th:
                    continue
                i = bisect.bisect_right(starts[t2], t) - 1
                if i >= 0 and iv[t2][i][1] >= t:
                    n += 1
            return n
        line = []
        for d in (0.0, -0.3, -0.2, 0.2, 0.3):
            bins = {0: [], 1: [], 2: []}
            for gap, hl, pe, sh, se, th, mid in r['conc'][G2]:
                bins[min(others_in_g2(mid + d, th), 2)].append(gap * 1e3)
            m = {k: (st.mean(v) if v else float('nan')) for k, v in bins.items()}
            line.append('d=%+.1f: %.1f [%d] | %.1f [%d] | %.1f [%d]  (2+ minus 0: %+.1f)' % (d, m[0], len(bins[0]), m[1], len(bins[1]), m[2], len(bins[2]), m[2] - m[0]))
        print('  %-4s mean G2 gap ms, other lanes in G2 = 0 | 1 | 2+ [n]' % nm)
        for l in line:
            print('       ' + l)
