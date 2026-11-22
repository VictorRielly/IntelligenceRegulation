#!/usr/bin/env python3
"""Tick 38 (queue item 64): host-gap tables of the three traced legs of the threads-per-lane test
(lt_trace_leg1 = 6 lanes x 5 threads, leg2 = 6 x 4, leg3 = 1 lane x 5 threads, 8 timed requests; both switches on).
Standard library only; run as: python3 -I -B this.py <results/zk60_lane_threads_20261122/raw>
Definitions as tick 37's script (request thread = thread with >1000 buffers; request starts at the first 'wprod' after a
non-wprod buffer, t=65 start-up products dropped; a block runs from the begin of one A commit (rows=2504) to the begin of the
next A commit on the same thread; kept when its first A commit begins inside [completion N, completion N+timed]).
New here: every buffer is assigned to the code phase of the TRANSITION that follows it (its own encode+queue+exec+wait plus
the gap to the next buffer), so each phase = buffers + gap and the phases sum to the block period exactly."""
import collections, json, lzma, os, re, statistics as st, sys

raw = sys.argv[1].rstrip('/')


def load(prefix, pid):
    f = '%s/traces/%s.%d.tsv.xz' % (raw, os.path.basename(prefix), pid)
    rows = []
    for i, line in enumerate(lzma.open(f, 'rt')):
        p = line.rstrip('\n').split('\t')
        if i == 0 or len(p) != 9:
            continue
        rows.append(dict(tag=p[0], det=p[1], th=int(p[2]), q=int(p[3]), beg=float(p[4]), com=float(p[5]),
                         gs=float(p[6]), ge=float(p[7]), dn=float(p[8])))
    return rows


def key(r):
    d, t = r['det'], r['tag']
    if t == 'commit':
        return 'commit ' + d.split(' log_n')[0]
    if t == 'gather':
        return 'gather ' + d.split(' nn')[0]
    if t == 'batch':
        m = re.match(r'slot (\d+)', d)
        return 'batch slot%02d' % int(m.group(1)) if m else 'batch ' + d.split(' (')[0]
    return t


def group(k):
    a, b = k
    if b.startswith('spfold') or a.startswith('spfold') or (a == 'batch slot22' and b.startswith('gather')) or (a.startswith('gather') and b.startswith('gather')):
        return 'G1 openings tail: slot 22 -> gather 38'
    if (a, b) == ('gather rows=38', 'commit rows=38'):
        return 'G2 gather 38 -> boundary commit'
    if (a, b) == ('commit rows=38', 'commit rows=2504'):
        return 'G3 boundary commit -> A commit'
    if (a, b) == ('commit rows=2504', 'commit rows=2606'):
        return 'G4 A commit -> H commit'
    if a == 'batch slot04' and b.startswith('batch slot1') or (a.startswith('batch slot0') and b.startswith('batch slot1') and int(a[-2:]) < 14 and int(b[-2:]) == 14):
        return 'G5 matmul slots 5-13 -> slot 14'
    if a.startswith('batch') or b.startswith('batch'):
        return 'G6 other slot gaps, H commit -> slots'
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
    return main, reqs


def analyse(L, rows):
    N, T = L['N'], L['timed']
    c = sorted(x['t_abs'] for x in L['completions'])
    lo, hi = c[N - 1], c[N + T - 1]
    main, reqs = requests(rows)
    nb = 0
    ph = collections.defaultdict(lambda: collections.Counter())
    keyg = collections.defaultdict(list)       # transition key -> list of gaps (s)
    blockper = []
    for t, v in reqs:
        A = [i for i, r in enumerate(v) if r['tag'] == 'commit' and 'rows=2504' in r['det']]
        for i0, i1 in zip(A, A[1:]):
            if not (lo <= v[i0]['beg'] <= hi):
                continue
            seg = v[i0:i1 + 1]
            nb += 1
            blockper.append(seg[-1]['beg'] - seg[0]['beg'])
            for p, q in zip(seg, seg[1:]):
                k = (key(p), key(q))
                g = group(k)
                c_ = ph[g]
                c_['encode'] += p['com'] - p['beg']
                c_['queue'] += p['gs'] - p['com']
                c_['exec'] += p['ge'] - p['gs']
                c_['wait'] += p['dn'] - p['ge']
                c_['gap'] += q['beg'] - p['dn']
                c_['n'] += 1
                keyg[k].append(q['beg'] - p['dn'])
    out = dict(nb=nb, period=sum(blockper) / nb * 1e3, sd_period=st.pstdev(blockper) * 1e3,
               ph={g: {k: (v / nb * 1e3 if k != 'n' else v / nb) for k, v in c.items()} for g, c in ph.items()},
               keyg={k: (sum(v) / nb * 1e3, len(v) / nb, st.median(v) * 1e3) for k, v in keyg.items()}, main=main)
    for g in out['ph']:
        c = out['ph'][g]
        c['total'] = c['encode'] + c['queue'] + c['exec'] + c['wait'] + c['gap']
    return out


legs = json.load(open(raw + '/lt_trace/t2_results.json'))['legs']
names = ['6x5', '6x4', '1x5']
res = {}
for nm, L in zip(names, legs):
    rows = load(L['trace_prefix'], L['server_pid'])
    res[nm] = analyse(L, rows)
    r = res[nm]
    print('=== leg %s: lanes %d threads %d, %d records, %d request threads, %d blocks kept, traced rate %.2f tok/s' % (
        nm, L['lanes'], L['threads'], len(rows), len(r['main']), r['nb'], L['rate']))
    s = sum(v['total'] for v in r['ph'].values())
    print('   mean block period %.2f ms (sd %.1f); sum of phases %.2f ms; difference %.4f ms' % (r['period'], r['sd_period'], s, s - r['period']))

order = sorted(res['6x5']['ph'])
print('\n=== (a) phase table, ms per block: encode / queue / exec / wait / gap / total ===')
for nm in names:
    r = res[nm]
    print('--- %s (period %.1f ms)' % (nm, r['period']))
    for g in sorted(r['ph']):
        c = r['ph'][g]
        print('  %-46s enc %6.1f q %6.1f ex %6.1f wt %6.1f gap %6.1f | total %7.1f (%4.1f%%) n/blk %.2f' % (
            g, c['encode'], c['queue'], c['exec'], c['wait'], c['gap'], c['total'], 100 * c['total'] / r['period'], c['n']))
    tot = collections.Counter()
    for c in r['ph'].values():
        for k in ('encode', 'queue', 'exec', 'wait', 'gap'):
            tot[k] += c[k]
    print('  %-46s enc %6.1f q %6.1f ex %6.1f wt %6.1f gap %6.1f' % ('all phases', tot['encode'], tot['queue'], tot['exec'], tot['wait'], tot['gap']))

print('\n=== (b) ratio 6x4 over 6x5 by phase (ideal 1/threads scaling would give 1.25; 1.00 = no change with the fifth thread) ===')
print('%-46s %8s %8s %6s | %7s %7s %7s | %7s %7s %7s' % ('phase', 'tot5', 'tot4', 'r_tot', 'gap5', 'gap4', 'r_gap', 'host5', 'host4', 'r_host'))
rows_b = []
for g in order:
    a, b = res['6x5']['ph'][g], res['6x4']['ph'].get(g)
    if b is None:
        continue
    h5, h4 = a['encode'] + a['gap'], b['encode'] + b['gap']
    rows_b.append((b['total'] - a['total'], g, a, b, h5, h4))
for d, g, a, b, h5, h4 in sorted(rows_b, reverse=True):
    print('%-46s %8.1f %8.1f %6.3f | %7.1f %7.1f %6.3f | %7.1f %7.1f %6.3f  (4 minus 5: %+.1f ms)' % (
        g, a['total'], b['total'], b['total'] / a['total'], a['gap'], b['gap'], b['gap'] / a['gap'], h5, h4, h4 / h5, d))
print('period 6x5 %.1f, 6x4 %.1f, ratio %.4f' % (res['6x5']['period'], res['6x4']['period'], res['6x4']['period'] / res['6x5']['period']))

print('\n--- per-transition keys, 6x5 against 6x4 (gap ms per block), largest 6x4-minus-6x5 first and the largest unchanged ones')
K5, K4 = res['6x5']['keyg'], res['6x4']['keyg']
ks = set(K5) | set(K4)
kd = sorted(((K4.get(k, (0, 0, 0))[0] - K5.get(k, (0, 0, 0))[0], k) for k in ks), reverse=True)
print('%8s %8s %8s %6s %6s  %s' % ('4-5', 'gap5', 'gap4', 'n5', 'n4', 'transition'))
for d, k in kd[:16]:
    a, b = K5.get(k, (0, 0, 0)), K4.get(k, (0, 0, 0))
    print('%8.2f %8.2f %8.2f %6.2f %6.2f  %s -> %s' % (d, a[0], b[0], a[1], b[1], k[0], k[1]))
print('sum of positive 4-5 differences %.1f ms; sum of negative %.1f ms' % (sum(d for d, k in kd if d > 0), sum(d for d, k in kd if d < 0)))
print('--- the 16 largest gap keys in 6x5 and their 6x4/6x5 ratio (a key near 1.0 does not scale with threads)')
big = sorted(((v[0], v[1], v[2], k) for k, v in K5.items()), reverse=True)[:16]
for s, n, med, k in big:
    b = K4.get(k, (0, 0, 0))
    print('%8.2f ms 5thr (%.2f/blk, med %.3f ms) | 4thr %8.2f ms ratio %.3f | %s -> %s' % (s, n, med, b[0], b[0] / s if s else float('nan'), k[0], k[1]))

print('\n=== (c) one lane (1x5) against six lanes (6x5), ms per block, request thread ===')
print('%-46s %8s %8s %6s | %7s %7s %7s | %7s %7s %7s | %7s %7s %7s' % ('phase', 'tot1', 'tot6', 'x', 'gap1', 'gap6', 'x', 'enc1', 'enc6', 'x', 'wait1', 'wait6', 'x'))
for g in order:
    a, b = res['1x5']['ph'].get(g), res['6x5']['ph'][g]
    if a is None:
        continue
    f = lambda x, y: y / x if x else float('nan')
    print('%-46s %8.1f %8.1f %6.3f | %7.1f %7.1f %6.3f | %7.1f %7.1f %6.3f | %7.1f %7.1f %6.3f' % (
        g, a['total'], b['total'], f(a['total'], b['total']), a['gap'], b['gap'], f(a['gap'], b['gap']),
        a['encode'], b['encode'], f(a['encode'], b['encode']), a['wait'] + a['queue'], b['wait'] + b['queue'], f(a['wait'] + a['queue'], b['wait'] + b['queue'])))
print('period: 1x5 %.1f ms, 6x5 %.1f ms, x%.3f' % (res['1x5']['period'], res['6x5']['period'], res['6x5']['period'] / res['1x5']['period']))
print('--- the 16 largest gap keys at six lanes against one lane (gap ms per block)')
K1 = res['1x5']['keyg']
for s, n, med, k in big:
    b = K1.get(k, (0, 0, 0))
    print('%8.2f ms 6 lanes (med %.3f) | 1 lane %8.2f (med %.3f) ratio %.2f | %s -> %s' % (s, med, b[0], b[2], s / b[0] if b[0] else float('nan'), k[0], k[1]))
