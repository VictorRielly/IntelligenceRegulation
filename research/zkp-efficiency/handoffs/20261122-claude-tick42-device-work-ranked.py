#!/usr/bin/env python3
"""Tick 42 (queue item 58): which device work per request could come off the device, ranked.
Standard library only; run as  python3 -I -B this.py <results/zk60_lanes_trace_20261121/raw>
Reads leg 1 (1 lane x 5 threads, 6 timed requests) and leg 2 (6 lanes x 5 threads, 48 timed requests) of the lanes trace
(.tsv.xz) and t2_results.json for the completion times.  Window = host BEGIN time between completion N and N+timed (the
trace_summary.py definition).  Everything else is arithmetic on figures cited in the handoff."""
import collections, json, lzma, os, re, sys

raw = sys.argv[1].rstrip('/')


def load(leg_file, pid_hint):
    rows = []
    for i, line in enumerate(lzma.open(leg_file, 'rt')):
        p = line.rstrip('\n').split('\t')
        if i == 0 or len(p) != 9:
            continue
        rows.append((p[0], p[1], int(p[2]), int(p[3]), float(p[4]), float(p[5]), float(p[6]), float(p[7]), float(p[8])))
    return rows


def key(tag, det):
    if tag == 'wprod':
        return 'wprod ' + det
    if tag == 'batch':
        m = re.match(r'slot (\d+)', det)
        return 'batch slot%02d' % int(m.group(1)) if m else 'batch ' + det[:30]
    if tag == 'commit':
        return 'commit ' + det.split(' log_n')[0]
    if tag == 'gather':
        return 'gather ' + det.split(' nn')[0]
    return tag + ' ' + det[:30]


def leg_table(res_json, leg_index, tracefile):
    L = json.load(open(res_json))['legs'][leg_index]
    N, T = L['N'], L['timed']
    c = sorted(x['t_abs'] for x in L['completions'])
    lo, hi = c[N - 1], c[N + T - 1]
    rows = [r for r in load(tracefile, None) if lo <= r[4] <= hi]
    B = 26 * T
    e = collections.Counter()
    n = collections.Counter()
    for r in rows:
        k = key(r[0], r[1])
        e[k] += (r[7] - r[6]) * 1e3 / B
        n[k] += 1.0 / B
    return e, n, B


e1, n1, B1 = leg_table(raw + '/tr_leg1/t2_results.json', 0, raw + '/traces/tr_leg1_leg1.37969.tsv.xz')
e2, n2, B2 = leg_table(raw + '/tr_main/t2_results.json', 0, raw + '/traces/tr_main_leg2.39067.tsv.xz')
tot1, tot2 = sum(e1.values()), sum(e2.values())
REQ1 = tot1 * 26 / 1e3
print('leg 1: %d block-equivalents, device execution %.3f ms per block = %.4f s per request (README: 2.968 s)' % (B1, tot1, REQ1))
print('leg 2: %d block-equivalents, device execution %.3f ms per block' % (B2, tot2))

# ---- (a) table of keys
print('\n(a) one lane (leg 1) and six lanes (leg 2): ms per block (= per 26th of a request), share of the request, x stretch')
print('%-48s %6s %9s %8s %7s %9s %7s' % ('key', 'n/blk', 'ms/req L1', '% L1', 'six ms', '% six', 'x'))
order = sorted(e1, key=lambda k: -e1[k])
cum = 0
for k in order:
    cum += e1[k]
    six = e2.get(k, 0.0)
    print('%-48s %6.2f %9.2f %7.2f%% %7.2f %7.2f%% %6.2f' % (k, n1[k], e1[k] * 26, 100 * e1[k] / tot1, six, 100 * six / tot2, six / e1[k] if e1[k] else 0))
print('top 8 share (one lane) %.1f%%' % (100 * sum(e1[k] for k in order[:8]) / tot1))

groups = collections.OrderedDict([
    ('zero-check slots (batch)', lambda k: k.startswith('batch')),
    ('commits A, H (rows 2606, 2504)', lambda k: k in ('commit rows=2606', 'commit rows=2504')),
    ('other commits (38, 76, 41, 6 rows)', lambda k: k.startswith('commit') and k not in ('commit rows=2606', 'commit rows=2504')),
    ('gathers', lambda k: k.startswith('gather')),
    ('sealing products (wprod)', lambda k: k.startswith('wprod')),
])
print('\nby group, ms per block (one lane / six lanes) and share:')
for g, f in groups.items():
    a = sum(v for k, v in e1.items() if f(k))
    b = sum(v for k, v in e2.items() if f(k))
    print('%-40s %7.2f %5.1f%% | %7.2f %5.1f%%  x%.2f' % (g, a, 100 * a / tot1, b, 100 * b / tot2, b / a if a else 0))

# ---- (b) sealing products, CPU against device
print('\n(b) the sealing products: device ms against CPU thread-ms')
# app shapes, t = 128 rows; products from trace keys.  The down projection's two int16 halves are the k=9216 key (A26).
prods = [
    # name, key detail, MACs per buffer (t*k*n), buffers per block, CPU path
    ('gate, up (4096 -> 16384)', 't=128 k=4096 n=16384 in_out=1', 128 * 4096 * 16384, 2),
    ('down halves (9216 -> 4096, hi and lo)', 't=128 k=9216 n=4096 in_out=1', 128 * 9216 * 4096, 2),
    ('Q, AO (4096 -> 4096)', 't=128 k=4096 n=4096 in_out=0', 128 * 4096 * 4096, 2),
    ('K, V (4096 -> 1024)', 't=128 k=4096 n=1024 in_out=0', 128 * 4096 * 1024, 2),
]
# A4 (results/zk60_effplan_20261105/a4/README.md): seven products alone, CPU 85 ms, 32 threads, W16R2 8B T128, best of 5
A4_CPU_MS, A4_THREADS = 85.0, 32
# 8B shape, MACs for the seven products (Q, K, V, AO, gate, up, down); down inner 9216 (as the app's used columns) or 16384 (padded)
m8 = {}
for nm, dk in (('down inner 9216', 9216), ('down inner 16384', 16384)):
    m8[nm] = 128 * (2 * 4096 * 4096 + 2 * 4096 * 1024 + 2 * 4096 * 16384 + dk * 4096)
for nm, m in m8.items():
    print('  8B seven products, %s: %.2f G MAC -> A4 CPU rate %.3f T MAC/s on %d threads = %.2f G MAC/s per thread' % (
        nm, m / 1e9, m / (A4_CPU_MS / 1e3) / 1e12, A4_THREADS, m / (A4_CPU_MS / 1e3) / A4_THREADS / 1e9))
rate_thread = m8['down inner 16384'] / (A4_CPU_MS / 1e3) / A4_THREADS      # the faster CPU, so the conservative side for the claim
rate_thread_lo = m8['down inner 9216'] / (A4_CPU_MS / 1e3) / A4_THREADS
print('  CPU rate per thread used: %.1f G MAC/s (range %.1f to %.1f)' % (rate_thread / 1e9, rate_thread_lo / 1e9, rate_thread / 1e9))
LANE_THREADS = 5
R_PASS = 1.0 / 3.0         # tick 37: a net host ms passes one third into the period
R_DEV = 3.4                # tick 40, E2 central: a one-lane device ms is worth about 3.4 ms of period at six lanes
print('  break-even (CPU wall ms on the lane per device ms freed): R_dev / pass-through = %.1f at pass-through 1/3; %.1f at 1' % (R_DEV / R_PASS, R_DEV / 1.0))
print('%-40s %6s %9s %9s %10s %10s %8s' % ('product', 'GMAC', 'dev ms L1', 'dev ms 6', 'CPU thr-ms', 'CPU wall5', 'CPU/dev'))
tot_cpu_thr = 0.0
for nm, det, macs, nb in prods:
    k = 'wprod ' + det
    d1 = e1[k] / n1[k] * (nb if 'down' in nm else 1)     # device ms of ONE product (the down's two halves added)
    d6 = e2[k] / n2[k] * (nb if 'down' in nm else 1)
    cpu_thr = macs / rate_thread * 1e3                    # thread-ms of one product on the CPU, tiled16 speed
    tot_cpu_thr += cpu_thr * (1 if 'down' in nm else nb)
    print('%-40s %6.2f %9.2f %9.2f %10.1f %10.1f %8.0f' % (nm, macs / 1e9, d1, d6, cpu_thr, cpu_thr / LANE_THREADS, cpu_thr / LANE_THREADS / d1))
print('  per block: the seven products on the CPU at tiled16 speed = %.0f thread-ms = %.2f s on %d threads; per request (26 blocks) %.1f thread-s'
      % (tot_cpu_thr, tot_cpu_thr / LANE_THREADS / 1e3, LANE_THREADS, tot_cpu_thr * 26 / 1e3))
print('  device, one lane: %.2f ms per block, %.3f s per request' % (sum(v for k, v in e1.items() if k.startswith('wprod')), sum(v for k, v in e1.items() if k.startswith('wprod')) * 26 / 1e3))
rate6 = 44.047
req_period = 6 * 128 / rate6
print('  six lanes: one request every %.2f s (leg 2: 44.047 tok/s) on 32 cores = %.0f core-s; the CPU products need %.0f thread-s = %.0f%% of it'
      % (req_period / 6 * 1.0, 32 * req_period / 6, tot_cpu_thr * 26 / 1e3, 100 * tot_cpu_thr * 26 / 1e3 / (32 * req_period / 6)))
# R13 record of the out-of-i16 down projection on the CPU (A26): 37% of the prover's 139.5 CPU-s, 128 x 16384 x 4096
a26_cpu_s_per_block = 0.37 * 139.5 / 26
print('  A26 (R13, down on the CPU in i64 lanes, 128 x 16384 x 4096): 0.37 x 139.5 CPU-s / 26 blocks = %.2f CPU-s per block = %.1f G MAC/s per thread'
      % (a26_cpu_s_per_block, 128 * 16384 * 4096 / a26_cpu_s_per_block / 1e9))
down_macs = 128 * 9216 * 4096
print('  at that rate the app down projection (%.2f G MAC) would take %.2f thread-s per block, against %.1f ms on the device (two halves)'
      % (down_macs / 1e9, down_macs / (128 * 16384 * 4096 / a26_cpu_s_per_block), 2 * e1['wprod t=128 k=9216 n=4096 in_out=1'] / n1['wprod t=128 k=9216 n=4096 in_out=1']))

# ---- (c) the commits: transform against hash
print('\n(c) commits: tick 21 diag split at W16R2_8B per block: inverse 8.3, forward 14.0, hash 3.4 ms (f = 0.868); tick 28: installed block equal within 0.1 ms')
inv, fwd, hsh = 8.3, 14.0, 3.4
tot_diag = inv + fwd + hsh
ah = e1['commit rows=2606'] + e1['commit rows=2504']
print('  A + H in this trace (switch off): %.2f ms per block = %.1f%% of the request; coordinator measurement of the installed block 28.95 ms' % (ah, 100 * ah / tot1))
for nm, v in (('inverse NTT', inv), ('forward NTT', fwd), ('hash', hsh)):
    print('  %-12s %5.2f ms per block (scaled to trace) = %.1f%% of the request' % (nm, v / tot_diag * ah, 100 * v / tot_diag * ah / tot1))
print('  gathers (rows 2606, 2504, 38 ...): %.3f ms per block, %.2f%% of the request' % (sum(v for k, v in e1.items() if k.startswith('gather')), 100 * sum(v for k, v in e1.items() if k.startswith('gather')) / tot1))
print('  commit rows=38: %.3f ms per block (%.1f commits)' % (e1['commit rows=38'], n1['commit rows=38']))

# ---- (d) rate change of candidates
print('\n(d) rate change per candidate; rate% = ms of one-lane device demand per block x R x 26 ms / 16.4 s (0.16% per unit of R, tick 40)')
PER_UNIT = 26.0 / 16400.0 * 100
cands = [
    ('whole wprod to the CPU (all seven)', sum(v for k, v in e1.items() if k.startswith('wprod')), 0.78),
    ('K, V products to the CPU', 2 * e1['wprod t=128 k=4096 n=1024 in_out=0'] / n1['wprod t=128 k=4096 n=1024 in_out=0'], 0.78),
    ('Q, AO products to the CPU', 2 * e1['wprod t=128 k=4096 n=4096 in_out=0'] / n1['wprod t=128 k=4096 n=4096 in_out=0'], 0.78),
    ('gate, up to the CPU', 2 * e1['wprod t=128 k=4096 n=16384 in_out=1'] / n1['wprod t=128 k=4096 n=16384 in_out=1'], 0.78),
    ('commit hash only, half cut (ASSUMED)', 0.5 * hsh / tot_diag * ah, 1.0),
    ('commit NTT traffic-floor kernel (tick 23 at most 3 ms)', 3.0, 1.0),
    ('fused encoder (landed; tick 40 E1: 4.1 to 7.9 ms)', 6.0, 1.0),
]
print('%-56s %7s %8s | %-12s %-12s %-12s' % ('candidate', 'ms/blk', 'at six', 'R = 5.12', 'R = 3.4', 'R = 0'))
for nm, ms, f6 in cands:
    print('%-56s %7.2f %8.2f | %+10.2f%%  %+10.2f%%  %+10.2f%%' % (nm, ms, ms * f6, ms * f6 * PER_UNIT * 5.12, ms * f6 * PER_UNIT * 3.4, 0.0))

# ---- (e) the gate/up sealing buffers are bimodal at one lane (3 ms or 5 to 6.6 ms)
import statistics as st


def gate_up(tracefile, res_json, leg_index):
    L = json.load(open(res_json))['legs'][leg_index]
    N, T = L['N'], L['timed']
    c = sorted(x['t_abs'] for x in L['completions'])
    lo, hi = c[N - 1], c[N + T - 1]
    return [(r[7] - r[6]) * 1e3 for r in load(tracefile, None) if r[0] == 'wprod' and 'n=16384' in r[1] and lo <= r[4] <= hi]


print('\n(e) gate/up sealing buffer (t=128 k=4096 n=16384) duration, timed window')
for nm, tf, rj, li in (('leg 1 (1 lane)', raw + '/traces/tr_leg1_leg1.37969.tsv.xz', raw + '/tr_leg1/t2_results.json', 0),
                       ('leg 2 (6 lanes)', raw + '/traces/tr_main_leg2.39067.tsv.xz', raw + '/tr_main/t2_results.json', 0)):
    d = gate_up(tf, rj, li)
    fast = [x for x in d if x <= 4.5]
    slow = [x for x in d if x > 4.5]
    print('  %-16s n=%d median %.2f mean %.2f | fast (<=4.5 ms) %.0f%% median %.2f | slow %.0f%% median %.2f'
          % (nm, len(d), st.median(d), st.mean(d), 100 * len(fast) / len(d), st.median(fast) if fast else 0, 100 * len(slow) / len(d), st.median(slow) if slow else 0))
d1 = gate_up(raw + '/traces/tr_leg1_leg1.37969.tsv.xz', raw + '/tr_leg1/t2_results.json', 0)
fast_med = st.median([x for x in d1 if x <= 4.5])
excess = sum(x - fast_med for x in d1 if x > 4.5) / (len(d1) / 2.0) / 1.0   # ms per block, summed over the 2 buffers of a block
print('  if every one-lane gate/up buffer ran at the fast median (%.2f ms): %.2f ms per block less (%.1f%% of the one-lane request)' % (fast_med, excess, 100 * excess / tot1))

# ---- (e2) is the slow mode a property of the layer (weights) or of the moment?  Leg 1, all 7 sealing passes (the warm-up one too).
allrows = sorted(load(raw + '/traces/tr_leg1_leg1.37969.tsv.xz', None), key=lambda r: r[4])
passes, cur, prev = [], [], None
for r in allrows:
    if r[0] == 'wprod' and 't=65' not in r[1]:
        if prev is not None and r[4] - prev > 0.5:
            passes.append(cur)
            cur = []
        cur.append(r)
        prev = r[7]
passes.append(cur)
tab = collections.defaultdict(list)
for pa in passes:
    g = [r for r in pa if 'n=16384' in r[1]]
    for j, r in enumerate(g):
        tab[j // 2].append(1 if (r[7] - r[6]) * 1e3 > 4.5 else 0)
print('\n(e2) %d passes of %s buffers; share of slow gate/up buffers by block position (7 passes): %s' % (
    len(passes), sorted({len(p) for p in passes}), [round(sum(v) / len(v), 2) for k, v in sorted(tab.items())]))
print('     positions always slow or always fast: %d of %d' % (sum(1 for v in tab.values() if sum(v) in (0, len(v))), len(tab)))
for i, pa in enumerate(passes):
    g = [(r[7] - r[6]) * 1e3 for r in pa if 'n=16384' in r[1]]
    print('     pass %d: share slow %.2f' % (i, sum(1 for x in g if x > 4.5) / len(g)))
