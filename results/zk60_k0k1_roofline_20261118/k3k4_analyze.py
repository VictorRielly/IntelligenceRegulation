#!/usr/bin/env python3
"""Medians, IQRs and the pre-stated readings for K3a, K3b and K4 from k3k4_timing.log. usage: k3k4_analyze.py <log>"""
import re
import statistics as st
import sys
from collections import defaultdict


def q(v):
    s = sorted(v)
    qs = st.quantiles(s, n=4, method='inclusive')
    return st.median(s), qs[0], qs[2]


def fmt(v, nd=3):
    m, a, b = q(v)
    return f'{m:.{nd}f} (IQR {a:.{nd}f}-{b:.{nd}f}, {100 * (b - a) / m:.1f}%)', 100 * (b - a) / m


k3 = defaultdict(lambda: defaultdict(list))
k4 = defaultdict(list)
for ln in open(sys.argv[1]):
    m = re.match(r'K3RAW slot=(\w+) rep=(-?\d+) kernel=(\w+) total_ms=([\d.]+) rounds_ms=([\d.,]+)', ln)
    if m and int(m.group(2)) >= 0:
        k3[m.group(1)][m.group(3)].append((float(m.group(4)), [float(x) for x in m.group(5).split(',')]))
    m = re.match(r'K4RAW rep=(-?\d+) kind=(\w+) op=(\w+) param=(\d+) ms=([\d.]+)', ln)
    if m and int(m.group(1)) >= 0:
        k4[(m.group(2), m.group(3), int(m.group(4)))].append(float(m.group(5)))

spread = []
print('K3: later rounds from cap/4 to 1, ms per full round sequence; split arms run their G kernels back to back in one command buffer per round')
for slot in sorted(k3):
    d = k3[slot]
    rows = {}
    print(f'\n[{slot}] n = {len(d["v13"])} timed reps')
    for kn in ('v13', 'k3a', 'split2', 'split4'):
        tot = [t for t, _ in d[kn]]
        r5 = [sum(r[:5]) for _, r in d[kn]]
        rows[kn] = (tot, r5)
        s, p = fmt(tot)
        s5, _ = fmt(r5)
        spread.append((slot, kn, p))
        print(f'  {kn:7s} total {s}   rounds 1-5 {s5}')
    for kn in ('k3a', 'split2', 'split4'):
        for label, i in (('total', 0), ('rounds 1-5', 1)):
            r = st.median(rows[kn][i]) / st.median(rows['v13'][i])
            per = [a / b for a, b in zip(rows[kn][i], rows['v13'][i])]
            pm, pa, pb = q(per)
            print(f'  {kn}/v13 {label:10s}: {r:.3f}  (per-rep median {pm:.3f}, IQR {pa:.3f}-{pb:.3f})')
    r = st.median(rows['k3a'][0]) / st.median(rows['v13'][0])
    print(f'  K3a reading on total ({r:.3f}): ' + ('ARITHMETIC-BOUND (>= 0.80)' if r >= 0.8 else 'REGISTER PRESSURE / OCCUPANCY (<= 0.50)' if r <= 0.5 else 'MIXED (0.50 to 0.80)'))
    for kn in ('split2', 'split4'):
        r = st.median(rows[kn][0]) / st.median(rows['v13'][0])
        v = ('PASS (summed time at least 15% below v13)' if r <= 0.85 else 'FAIL (within 5% of v13 or slower)' if r >= 0.95 else 'SMALL (between)')
        print(f'  K3b {kn} reading on total ({r:.3f}, {100 * (1 - r):+.1f}% below v13): {v}')

print('\nK4: operation costs (2^20 threads; throughput = whole-GPU time over total operations)')
base = {}
for rep in (16, 128):
    print(f'\n throughput, {rep} repetitions of 64 ops per thread (2^20 x 8 chains x 8 x {rep} = {(1 << 20) * 64 * rep:,} ops)')
    for op in ('gl_add', 'gl_mul', 'f2_mul', 'f2_mulb'):
        v = k4[('thr', op, rep)]
        ms = st.median(v)
        ps = ms * 1e-3 / ((1 << 20) * 64 * rep) * 1e12
        base.setdefault(rep, {})[op] = ps
        s, p = fmt(v, 4)
        spread.append(('k4', f'{op}/{rep}', p))
        print(f'  {op:8s} {s} ms -> {ps:.4f} ps/op  ({1e3 / ps:.1f} Gop/s)  ratio to gl_add {ps / base[rep]["gl_add"]:.2f}')
print('\n dependent chain latency (32 threads, one SIMD group), ns per op = (t(65536) - t(16384)) / 49152')
for op in ('gl_add', 'gl_mul', 'f2_mul'):
    a, b = st.median(k4[('dep', op, 16384)]), st.median(k4[('dep', op, 65536)])
    lat = (b - a) * 1e6 / (65536 - 16384)
    for n in (16384, 65536):
        s, p = fmt(k4[('dep', op, n)], 4)
        spread.append(('k4', f'dep {op}/{n}', p))
    print(f'  {op:7s} t16384 {a:.4f} ms, t65536 {b:.4f} ms -> {lat:.2f} ns per dependent op')
print('\nspread flags (IQR over 10% of median):')
bad = [x for x in spread if x[2] > 10]
print('  none' if not bad else '\n'.join(f'  {a} {b}: {p:.1f}%' for a, b, p in bad))
