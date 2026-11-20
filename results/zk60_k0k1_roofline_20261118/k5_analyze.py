#!/usr/bin/env python3
"""K5 medians, IQRs, ratios to v13, the split curve, best mixed schedule (derived) and the pre-stated readings.
usage: k5_analyze.py <k5_timing.log>"""
import re
import statistics as st
import sys
from collections import defaultdict


def q(v):
    s = sorted(v)
    qs = st.quantiles(s, n=4, method='inclusive') if len(s) > 1 else [s[0], s[0], s[0]]
    return st.median(s), qs[0], qs[2]


data = defaultdict(lambda: defaultdict(list))   # slot -> arm -> [(total, [rounds])]
order = []
for ln in open(sys.argv[1]):
    m = re.match(r'K5RAW slot=(\w+) rep=(-?\d+) arm=(\w+) total_ms=([\d.]+) rounds_ms=([\d.,]+)', ln)
    if m and int(m.group(2)) >= 0:
        if m.group(1) not in order:
            order.append(m.group(1))
        data[m.group(1)][m.group(3)].append((float(m.group(4)), [float(x) for x in m.group(5).split(',')]))

spread = []
for slot in order:
    d = data[slot]
    arms = list(d.keys())
    nr = len(d['v13'][0][1])
    tot = {a: [t for t, _ in d[a]] for a in arms}
    r5 = {a: [sum(r[:5]) for _, r in d[a]] for a in arms}
    rmed = {a: [st.median([r[i] for _, r in d[a]]) for i in range(nr)] for a in arms}
    print(f'\n=== {slot}: n = {len(d["v13"])} timed reps, {nr} rounds')
    print(f'  {"arm":6s} {"total ms (IQR)":26s} {"ratio":>6s} {"rounds1-5 ms":>13s} {"ratio":>6s} {"per-rep ratio total (IQR)":>28s}')
    for a in arms:
        mt, lt, ht = q(tot[a]); m5, _, _ = q(r5[a])
        per = [x / y for x, y in zip(tot[a], tot['v13'])]
        pm, pl, ph = q(per)
        spread.append((slot, a, 100 * (ht - lt) / mt))
        print(f'  {a:6s} {mt:8.3f} ({lt:.3f}-{ht:.3f}) {mt / st.median(tot["v13"]):6.3f} {m5:13.3f} {m5 / st.median(r5["v13"]):6.3f}   {pm:.3f} ({pl:.3f}-{ph:.3f})')
    # derived schedules from per-round medians
    cand = [a for a in arms if a not in ('k1',)]
    best = [min(cand, key=lambda a: rmed[a][i]) for i in range(nr)]
    best_total = sum(min(rmed[a][i] for a in cand) for i in range(nr))
    v13_total = sum(rmed['v13'])
    print(f'  DERIVED (sums of per-round medians): v13 {v13_total:.3f} ms; best arm chosen per round {best_total:.3f} ms ({best_total / v13_total:.3f}); '
          f'arms chosen for rounds 1..{nr}: {" ".join(best)}')
    for a in cand:
        if a == 'v13':
            continue
        bj, bt = 0, v13_total
        for j in range(1, nr + 1):
            t = sum(rmed[a][:j]) + sum(rmed['v13'][j:])
            if t < bt:
                bj, bt = j, t
        print(f'    {a:5s} in rounds 1..{bj}, v13 after: {bt:.3f} ms ({bt / v13_total:.3f}); {a} all rounds: {sum(rmed[a]):.3f} ({sum(rmed[a]) / v13_total:.3f})')
    print('  per-round median ms, v13 | s4 | a4 | g4:')
    for i in range(min(nr, 8)):
        print(f'    round {i + 1}: {rmed["v13"][i]:.4f} | {rmed["s4"][i]:.4f} | {rmed["a4"][i]:.4f} | {rmed["g4"][i]:.4f}')
    # pre-stated readings
    R = lambda a: st.median(tot[a]) / st.median(tot['v13'])
    if slot.endswith('r0') or slot.startswith('b'):
        kind = 'K5e (round 0)' if slot.endswith('r0') else 'K5d (8B)'
        for a in ('s2', 'a2', 's4', 'a4'):
            r = R(a)
            v = 'PASS (>= 15% below)' if r <= 0.85 else 'FAIL (within 5% or slower)' if r >= 0.95 else 'SMALL'
            print(f'  {kind} {a}: ratio {r:.3f} -> {v}')
    r_g, r_gb, r_s4, r_a4 = R('g4'), R('g4b'), R('s4'), R('a4')
    print(f'  K5b: g4 {r_g:.3f}, g4b {r_gb:.3f}; s4 {r_s4:.3f}, a4 {r_a4:.3f}; |g4 - s4| = {abs(r_g - r_s4) * 100:.1f} pts, |g4 - v13| = {abs(r_g - 1) * 100:.1f} pts')
    for a, r in (('g4', r_g), ('g4b', r_gb)):
        w_s = abs(r - r_s4) <= 0.03
        w_v = abs(r - 1) <= 0.03
        print(f'    {a}: ' + ('within 3 pts of the G=4 split (no extra dispatches needed)' if w_s else '') +
              ('within 3 pts of v13 (the separate kernels do the work)' if w_v else '') + ('' if (w_s or w_v) else 'neither within 3 pts (between)'))

print('\nspread flags (IQR over 10% of median):')
bad = [x for x in spread if x[2] > 10]
print('  none' if not bad else '\n'.join(f'  {a} {b}: {p:.1f}%' for a, b, p in bad))
