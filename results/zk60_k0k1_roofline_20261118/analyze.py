#!/usr/bin/env python3
"""Medians, interquartile ranges and the pre-stated readings from timing.log. Reads only; prints a report.
usage: analyze.py <timing.log>"""
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
    return f'{m:.{nd}f} (IQR {a:.{nd}f}-{b:.{nd}f}, {100 * (b - a) / m:.1f}% of median)', 100 * (b - a) / m


k1 = defaultdict(lambda: defaultdict(list))      # slot -> kernel -> [(rep, total, rounds)]
k0 = defaultdict(list)
for ln in open(sys.argv[1]):
    m = re.match(r'K1RAW slot=(\w+) rep=(-?\d+) kernel=(\w+) total_ms=([\d.]+) rounds_ms=([\d.,]+)', ln)
    if m and int(m.group(2)) >= 0:
        k1[m.group(1)][m.group(3)].append((int(m.group(2)), float(m.group(4)), [float(x) for x in m.group(5).split(',')]))
    m = re.match(r'K0RAW rep=(-?\d+) kernel=(\w+) ms=([\d.]+)', ln)
    if m and int(m.group(1)) >= 0:
        k0[m.group(2)].append(float(m.group(3)))

polluted = []
print('K1: later rounds from cap/4 down to 1, GPU timestamps, ms per full round sequence (n reps each)')
for slot in sorted(k1):
    d = k1[slot]
    n = len(d['v13'])
    print(f'\n[{slot}] n = {n} timed reps (after warm-up), kernels interleaved v13, k1, k1b per rep')
    rows = {}
    for kn in ('v13', 'k1', 'k1b'):
        tot = [t for _, t, _ in d[kn]]
        r1 = [r[0] for _, _, r in d[kn]]
        r5 = [sum(r[:5]) for _, _, r in d[kn]]
        rows[kn] = (tot, r1, r5)
        s_tot, p = fmt(tot)
        s_r1, p1 = fmt(r1, 4)
        s_r5, p5 = fmt(r5)
        print(f'  {kn:4s} total {s_tot}\n       round 1 {s_r1}\n       rounds 1-5 {s_r5}')
        polluted.append((slot, kn, p))
    for kn in ('k1', 'k1b'):
        for label, i in (('total', 0), ('round 1', 1), ('rounds 1-5', 2)):
            ratio = st.median(rows[kn][i]) / st.median(rows['v13'][i])
            per = [a / b for a, b in zip(rows[kn][i], rows['v13'][i])]
            pm, pa, pb = q(per)
            print(f'  {kn} / v13, {label:10s}: ratio of medians {ratio:.3f}; per-rep ratio median {pm:.3f} (IQR {pa:.3f}-{pb:.3f})')
    r = st.median(rows['k1'][0]) / st.median(rows['v13'][0])
    verdict = ('LOAD-BOUND (K1 within about 20% of v13: arithmetic ideas dead)' if r >= 0.8 else
               'BODY STILL COSTS (K1 under about half of v13)' if r < 0.5 else 'MIXED (between half and 80%)')
    print(f'  pre-stated reading on the TOTAL (K1 over v13 = {r:.3f}): {verdict}')

print('\nK0: slot 18 window-1 shape, 22 tables, 2^20 pairs; fold reads 738,197,504 B and writes 369,098,752 B (1,107,296,256 B moved)')
RD, WR = 738197504, 369098752
res = {}
for kn in ('fold_ext', 'fold_mixed', 'copy_pat', 'copy_vec'):
    v = k0[kn]
    s, p = fmt(v, 4)
    gbs = [(RD + WR) / (t * 1e-3) / 1e9 for t in v]
    s2, _ = fmt(gbs, 1)
    res[kn] = (st.median(v), st.median(gbs))
    print(f'  {kn:10s} n={len(v)} ms {s}\n             GB/s (read+write bytes over time) {s2}')
    polluted.append(('k0', kn, p))
fold_share = res['fold_ext'][0] / 4.730
print(f'\n  fold_ext median {res["fold_ext"][0]:.3f} ms = {100 * fold_share:.1f}% of slot 18 window 1 (4.730 ms); '
      f'fold_mixed (10 of 22 tables base, c1 = 0) {res["fold_mixed"][0]:.3f} ms = {100 * res["fold_mixed"][0] / 4.730:.1f}%')
for kn in ('fold_ext', 'copy_pat', 'copy_vec'):
    g = res[kn][1]
    # "near 500" is not numerically pre-stated; read here as 450-550. Anything else under 700 is UNDECIDED.
    v = ('NEAR 500, read as 450-550 (evaluation windows at saturation; single fetch pays)' if 450 <= g <= 550 else
         'AT OR ABOVE 700 (not bandwidth-bound; gain capped near 4% of block GPU)' if g >= 700 else
         'UNDECIDED (not near 500 and under 700)')
    print(f'  {kn}: {g:.0f} GB/s -> {v}')
print('\nspread flags (IQR over 10% of median):')
bad = [(a, b, p) for a, b, p in polluted if p > 10]
print('  none' if not bad else '\n'.join(f'  {a} {b}: IQR {p:.1f}% of median' for a, b, p in bad))
