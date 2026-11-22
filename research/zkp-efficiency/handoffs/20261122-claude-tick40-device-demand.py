#!/usr/bin/env python3
"""Tick 40 (queue item 65): device execution per block by buffer kind, one lane (1x5, lt_trace_leg3) against six lanes
(6x5, lt_trace_leg1), request thread only, both switches on.  Standard library only; run as
    python3 -I -B this.py <results/zk60_lane_threads_20261122/raw>
Definitions are tick 38's (request thread = thread with > 1000 buffers; request starts at the first 'wprod' after a
non-wprod buffer, t=65 start-up products dropped; a block runs from the begin of one A commit (rows=2504) to the begin of
the next on the same thread; kept when its first A commit begins inside [completion N, completion N+timed]).
New here: every buffer of the block (all but the closing A commit, which belongs to the next block) is charged to a KIND,
its execution time gs..ge is summed per kind, and the kinds are checked against tick 38's 98.5 and 217.9 ms."""
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


SLOTINFO = {}


def kind(r):
    d, t = r['det'], r['tag']
    if t == 'commit':
        return 'commit ' + d.split(' log_n')[0]
    if t == 'gather':
        return 'gather ' + d.split(' nn')[0]
    if t == 'spfold':
        return 'spfold ' + d.split(' active')[0]
    if t == 'batch':
        m = re.match(r'slot (\d+) \((.*?)\) at .*?: (\d+) tables \((\d+) base\), (\d+) nodes.*?n_vars=(\d+)', d)
        if m:
            n = int(m.group(1))
            SLOTINFO[n] = (m.group(2), int(m.group(3)), int(m.group(4)), int(m.group(5)), int(m.group(6)))
            return 'batch slot%02d' % n
        return 'batch ' + d.split(' (')[0]
    return t


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
    ex = collections.Counter()
    cnt = collections.Counter()
    per_block_total = []
    for t, v in reqs:
        A = [i for i, r in enumerate(v) if r['tag'] == 'commit' and 'rows=2504' in r['det']]
        for i0, i1 in zip(A, A[1:]):
            if not (lo <= v[i0]['beg'] <= hi):
                continue
            nb += 1
            tot = 0.0
            for r in v[i0:i1]:       # the closing A commit (v[i1]) belongs to the next block
                k = kind(r)
                e = r['ge'] - r['gs']
                ex[k] += e
                cnt[k] += 1
                tot += e
            per_block_total.append(tot)
    return dict(nb=nb, ex={k: v / nb * 1e3 for k, v in ex.items()}, cnt={k: v / nb for k, v in cnt.items()},
                sd=st.pstdev(per_block_total) * 1e3)


legs = json.load(open(raw + '/lt_trace/t2_results.json'))['legs']
res = {}
for nm, L in zip(['6x5', '6x4', '1x5'], legs):
    if nm == '6x4':
        continue
    rows = load(L['trace_prefix'], L['server_pid'])
    res[nm] = analyse(L, rows)

e1, e6 = res['1x5']['ex'], res['6x5']['ex']
c1, c6 = res['1x5']['cnt'], res['6x5']['cnt']
t1, t6 = sum(e1.values()), sum(e6.values())
print('blocks kept: 1x5 %d, 6x5 %d' % (res['1x5']['nb'], res['6x5']['nb']))
print('sum of kinds: 1 lane %.3f ms, 6 lanes %.3f ms (tick 38: 98.5 and 217.9; differences %.2f%% and %.2f%%)' % (
    t1, t6, 100 * (t1 / 98.5 - 1), 100 * (t6 / 217.9 - 1)))
print('stretch of the sum x%.3f; added %.1f ms' % (t6 / t1, t6 - t1))
print()
print('%-18s %6s %6s | %8s %8s %6s %8s | %6s %6s | %s' % ('kind', 'n1', 'n6', 'ex1 ms', 'ex6 ms', 'x', 'added', '%1', '%6', 'slot name / tables (base) / nodes / n_vars'))
order = sorted(e1, key=lambda k: -e1[k])
cum1 = cum6 = 0
for k in order:
    a, b = e1[k], e6.get(k, 0)
    cum1 += a
    cum6 += b
    info = ''
    m = re.match(r'batch slot(\d+)', k)
    if m and int(m.group(1)) in SLOTINFO:
        s = SLOTINFO[int(m.group(1))]
        info = '%s | %d (%d) tables, %d nodes, n_vars %d' % s
    print('%-18s %6.2f %6.2f | %8.2f %8.2f %6.2f %8.2f | %5.1f%% %5.1f%% | %s' % (
        k, c1[k], c6.get(k, 0), a, b, b / a if a else float('nan'), b - a, 100 * a / t1, 100 * b / t6, info))
print('cumulative top-10 share: 1 lane %.1f%%, 6 lanes %.1f%%' % (
    100 * sum(e1[k] for k in order[:10]) / t1, 100 * sum(e6.get(k, 0) for k in order[:10]) / t6))
extra = [k for k in e6 if k not in e1]
print('kinds only at six lanes:', extra)
print()
print('--- grouped')
G = collections.OrderedDict([
    ('commit (6 per block)', lambda k: k.startswith('commit')),
    ('gather', lambda k: k.startswith('gather')),
    ('spfold', lambda k: k.startswith('spfold')),
    ('wprod', lambda k: k == 'wprod'),
    ('batch slots 0-4 (host-built small)', lambda k: k.startswith('batch slot') and int(k[-2:]) <= 4),
    ('batch slots 14-17 (zero-checks)', lambda k: k.startswith('batch slot') and 14 <= int(k[-2:]) <= 17),
    ('batch slot 18', lambda k: k == 'batch slot18'),
    ('batch slots 19-23', lambda k: k.startswith('batch slot') and 19 <= int(k[-2:]) <= 23),
    ('batch other', lambda k: k.startswith('batch') and not k.startswith('batch slot')),
])
used = set()
for g, f in G.items():
    ks = [k for k in e1 if f(k) and k not in used]
    used |= set(ks)
    a = sum(e1[k] for k in ks)
    b = sum(e6.get(k, 0) for k in ks)
    print('%-38s 1 lane %7.2f ms  6 lanes %7.2f ms  x%.2f  added %7.2f (%.0f%% of the %.1f added)' % (
        g, a, b, b / a if a else float('nan'), b - a, 100 * (b - a) / (t6 - t1), t6 - t1))
rest = [k for k in e1 if k not in used]
print('ungrouped:', rest)

# ------------------------------------------------------------------------------------------------------------
# (c) exchange rate R = ms of block period per ms of one-lane device demand, at six lanes.  Inputs are copied from
# records (cited per line); all arithmetic is here.
print()
print('=== (c) exchange rate arithmetic (inputs from the cited records) ===')
L = 6
P6, D1, D6 = 504.96, t1, t6                    # tick 38 block period (6x5 traced), this script's one-lane and six-lane demand
c_work = L * D1 / P6
print('structural: six blocks of one-lane demand %.1f ms per %.1f ms of period: overlap factor c = %.3f' % (L * D1, P6, c_work))
print('  if the device were the only constraint, R_max = L / c = %.2f ms of period per one-lane ms; if the host were, R = 0' % (L / c_work))
# request time per block-equivalent: a request is 128 tokens, 6 lanes, rate r tok/s -> 6*128/r s, 26 blocks
def req_s(r):
    return L * 128 / r
def per_block_ms(r_off, g):
    return req_s(r_off) * (1 - 1 / (1 + g)) / 26 * 1e3
BLOCK_SHARE = 26.8 / (per_block_ms(42.491, 0.0494))      # fused traced pair: block wall -26.8 ms against the rate-implied
print('share of the request-time gain that shows in block wall (fused traced pair: -26.8 ms against rate-implied %.1f): %.2f' % (
    per_block_ms(42.491, 0.0494), BLOCK_SHARE))
print()
print('E1 fused RS encoder, app profile, untraced pairs (zk60_fused_rs_app_20261121): gains +4.43 +2.87 +3.06 +1.43 %, off level about 43.3 tok/s')
r_off = 43.3
for g in (0.0143, 0.0295, 0.0443):
    print('   gain %+.2f%% -> request time -%.0f ms, block-equivalent -%.1f ms, block wall (x%.2f) -%.1f ms' % (
        100 * g, req_s(r_off) * (1 - 1 / (1 + g)) * 1e3, per_block_ms(r_off, g), BLOCK_SHARE, per_block_ms(r_off, g) * BLOCK_SHARE))
dD1_low = 28.95 - (e1['commit rows=2504'] + e1['commit rows=2606'])      # installed block, quiet solo, switch off (zk60_w16r2_shield_block_20261120), minus this one-lane trace (switch on)
dD6 = 17.0                                    # traced pair prover exec, six lanes, off minus on
dD1_high = dD6 / 212.2 * D1                   # same relative cut applied to the one-lane demand
print('   one-lane demand cut: low %.2f ms (28.95 solo off - %.2f traced on), high %.2f ms (17.0 of 212.2 ms six-lane exec = %.1f%% of %.1f)' % (
    dD1_low, e1['commit rows=2504'] + e1['commit rows=2606'], dD1_high, 100 * dD6 / 212.2, D1))
for g in (0.0143, 0.0295, 0.0443):
    pb = per_block_ms(r_off, g) * BLOCK_SHARE
    print('   gain %+.2f%%: R = %.2f (dD1 %.1f) to %.2f (dD1 %.1f)' % (100 * g, pb / dD1_low, dD1_low, pb / dD1_high, dD1_high))
print()
print('E2 interpolation from the host pass-through (tick 37: a host ms cut passed a third; the device returned it as exec +21.1 and queue +14.6):')
for th in (0.25, 0.33, 0.40):
    w = 1 - th
    print('   host pass-through %.2f -> device share w = %.2f -> R = w L/c = %.2f' % (th, w, w * L / c_work))
print('   (a closed two-phase model: period = host + device phase, device phase a shared server; crude, one measurement)')
print()
print('E3 tick 33 model (calibration, not a measurement): 1 ms per block = x1.007 to x1.011 -> %.1f to %.1f ms of period at P = %.0f' % (
    0.007 * P6, 0.011 * P6, P6))
print()
print('Composed bundle cross-check (zk60_composed_app_20261122, traced A and C, one pair): block wall -17.7 ms; execution +20.5 (spfold +9.5, commits -8.9,')
print('  all other kinds +19.9), queue +14.8, host time -53.2.  One-lane demand change: fused %.1f to %.1f, spfold +%.2f (this trace) -> about %+.1f to %+.1f ms;' % (
    -dD1_high, -dD1_low, e1['spfold rows=2504'] + e1['spfold rows=2606'] + e1['spfold rows=38'],
    -dD1_high + e1['spfold rows=2504'] + e1['spfold rows=2606'] + e1['spfold rows=38'], -dD1_low + e1['spfold rows=2504'] + e1['spfold rows=2606'] + e1['spfold rows=38']))
print('  yet exec+queue at six lanes rose by 35.3 ms: the stretch of device time depends on how many lanes are on the device at once, so R is not a constant.')
print()
print('=== (d) numbers for the cuts ===')
sp = e1['spfold rows=2504'] + e1['spfold rows=2606']
print('spfold kernel, installed shapes: bytes read 2504 x (16384+280) x 8 B = %.0f MB, partials written and re-read 13 x 37 x 16664 x 16 B = %.0f MB each way' % (
    2504 * 16664 * 8 / 1e6, 13 * 37 * 16664 * 16 / 1e6))
print('  at the K0 copy roofline of 700 GB/s: %.2f ms; gl_mul count 2 x nnz x cols = 2 x 5658 x 16664 = %.0f M at K4 220 Gop/s = %.2f ms; one-lane measured %.2f ms (A commit shape)' % (
    (2504 * 16664 * 8 + 2 * 13 * 37 * 16664 * 16) / 700e9 * 1e3, 2 * 5658 * 16664 / 1e6, 2 * 5658 * 16664 / 220e9 * 1e3, e1['spfold rows=2504']))
nd = {0: 11, 1: 11, 3: 8, 4: 11, 14: 16, 15: 14, 16: 12, 17: 15, 18: 17, 19: 9, 21: 9, 22: 8}
print('device rounds per block (trace nd of the 12 main slots): %d; dispatches at 3 to 4 per round: %d to %d' % (sum(nd.values()), 3 * sum(nd.values()), 4 * sum(nd.values())))
small = [k for k in e1 if k.startswith('batch slot') and e6.get(k, 0) and k in ('batch slot00', 'batch slot01', 'batch slot03', 'batch slot04', 'batch slot21', 'batch slot22', 'batch slot19', 'batch slot16')]
print('small-table slots 0,1,3,4,16,19,21,22: one lane %.2f ms, six lanes %.2f ms (x%.2f); big-table slots 14,15,17,18: %.2f and %.2f ms (x%.2f); commits x%.2f' % (
    sum(e1[k] for k in small), sum(e6[k] for k in small), sum(e6[k] for k in small) / sum(e1[k] for k in small),
    sum(e1['batch slot%d' % s] for s in (14, 15, 17, 18)), sum(e6['batch slot%d' % s] for s in (14, 15, 17, 18)),
    sum(e6['batch slot%d' % s] for s in (14, 15, 17, 18)) / sum(e1['batch slot%d' % s] for s in (14, 15, 17, 18)),
    (e6['commit rows=2504'] + e6['commit rows=2606']) / (e1['commit rows=2504'] + e1['commit rows=2606'])))
