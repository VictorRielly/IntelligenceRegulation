"""Tick 53 (queue item 87, H136b): bound the device time of a masked LogUp-GKR tree over one block's lookups on Metal,
from kernel timings already measured. Arithmetic only (standard library). Run: python3 -I -B <this file>.
Sources (all read by the tick): results/zk60_k0k1_roofline_20261118/{k5_analysis.txt,k5_timing.log,build/k5_b14.json,
build/k5_b18.json,README.md}; results/zk60_k9_sc_chain_20261123/README.md; research/zkp-efficiency/experiments/logup-gkr-20261101/
{README.md,projection.json,ZK_DESIGN_NOTE.md}; handoffs 20261122-claude-tick40 (slot ms), 20261124-claude-tick52 (A's share).
"""
import math, re, statistics, json, pathlib

K5 = pathlib.Path('/Users/victorrielly/IntelligenceRegulation/results/zk60_k0k1_roofline_20261118')

# ---- 1. measured round rates of the shipped zero-check round kernel (v13) at the W16R2_8B shapes -------------------
# per-round medians from k5_timing.log (reps >= 0), arm v13. b14: cap 2^19 (first timed round 2^17 pairs), 39 live tables,
# counts 40 f2_mul + 31 f2_mulb. b18: cap 2^21 (first timed round 2^19 pairs), 21 live tables, counts 25 + 13.
# round 0 of b18 (2^20 pairs): 4.437 ms (k5_analysis.txt, b18r0). np = 4 points per pair.
EB = 9.27 / 23.49      # K4: f2_mulb costs 0.395 of an f2_mul (README K4 table, ps per op)
def read_rounds(slot):
    rows = []
    for ln in (K5 / 'k5_timing.log').read_text().splitlines():
        m = re.match(r'K5RAW slot=%s rep=(-?\d+) arm=v13 total_ms=\S+ rounds_ms=(\S+)' % slot, ln)
        if m and int(m.group(1)) >= 0:
            rows.append([float(x) for x in m.group(2).split(',')])
    return [statistics.median(c) for c in zip(*rows)]
def eq_per_pair_point(ee, eb, tabs):
    # line values: one f2_mulb per loaded table at the 3 of 4 points with d >= 2 (README, K3/K4 section)
    return ee + EB * (eb + tabs * 0.75)
tables = {
    'b14 (slot 14, 8B)': dict(slot='b14', ee=40, eb=31, tabs=39, first_pairs=2**17),
    'b18 (slot 18, 8B)': dict(slot='b18', ee=25, eb=13, tabs=21, first_pairs=2**19),
}
# the K5 raw log names the shapes sh14/sh18 (Shieldstral R13) and b14/b18 (8B); read the 8B rows
rate = {}   # pairs -> ps per ee-equivalent, per shape
for name, t in tables.items():
    r = read_rounds(t['slot'])
    e = eq_per_pair_point(t['ee'], t['eb'], t['tabs'])
    d = {}
    for i, ms in enumerate(r):
        pairs = t['first_pairs'] >> i
        d[pairs] = (ms * 1e-3 / (pairs * 4)) / e * 1e12    # ps per ee-equivalent
    if t['slot'] == 'b18':
        d[2**20] = (4.437e-3 / (2**20 * 4)) / e * 1e12     # round 0, b18r0 median
    rate[name] = (e, d, r)
print('ee-equivalents per pair-point: ' + ', '.join('%s %.1f' % (n, v[0]) for n, v in rate.items()))
for n, v in rate.items():
    print(n, 'ps per ee-equivalent by pairs:', {('2^%d' % math.log2(p)): round(x, 1) for p, x in sorted(v[1].items(), reverse=True) if p >= 2**8})
best = rate['b18 (slot 18, 8B)'][1]     # low case: best measured shape (b18: 21 tables, bigger grid)
worst = rate['b14 (slot 14, 8B)'][1]    # high case: worst measured shape (b14: 39 tables)
def lowrate(p):
    ks = [k for k in best if k <= p]
    return best[max(ks)] if ks else best[min(best)]
def highrate(p):
    # worst shape where measured (pairs <= 2^17), above that the b14 value at 2^17 (not measured at larger grids)
    if p >= 2**17: return max(worst[2**17], best.get(p, 0))
    return max(worst.get(p, worst[min(worst)]), best.get(p, 0))

# ---- 2. the LogUp-GKR tree of the 2026-11-01 prototype (README): 2^25 leaves, sumcheck layers k = 24 .. 1, k rounds each
N = 25
LOOKUPS = 32_276_480
EE_PAIR_GENERIC = 13.0   # DERIVED: 3 points x (q1*(p0+lam*q0) + p1*q0 = 2 products, + eq = 1) -> 3 ee... see handoff section 1; fold 4 tables x 1 ee
# per point: p0*q1, p1*q0, q0*q1 folded as q1*(p0+lam*q0)+p1*q0 = 2 ee, times split-eq 1 ee = 3 ee; 3 points = 9; fold of 4 Fp2 tables = 4 ee
EE_PAIR_LEAFLAYER = 6.5  # ASSUMED half: p == 1 implicit, base-field leaves in the first two rounds
EE_BUILD_NODE = 3.0      # p = p0 q1 + p1 q0 (2), q = q0 q1 (1) per stored node
BYTES_PER_PAIR = 180.0   # COUNTED by the prototype: 116 B read + 64 B written per leaf, about one pair per leaf over the tree
BW = 700e9               # K0: 692-704 GB/s measured (copy and fold)
PROTO_EE = 10.4 * 2**25  # prototype COUNTED 10.4 Fp2-mult equivalents per leaf (1.7 build + 8.7 top-down)
layers = list(range(24, 0, -1))
ee_topdown = sum((EE_PAIR_LEAFLAYER if k == 24 else EE_PAIR_GENERIC) * 2**k for k in layers)  # sum of pairs over rounds of layer k ~ 2^k
ee_build = sum(EE_BUILD_NODE * 2**k for k in range(1, 25))
print('\nstructural ee per block: top-down %.1f M, build %.1f M, total %.1f M; prototype counted %.1f M (ratio %.3f)' % (
    ee_topdown/1e6, ee_build/1e6, (ee_topdown+ee_build)/1e6, PROTO_EE/1e6, (ee_topdown+ee_build)/PROTO_EE))

def tree_time(case):
    if case == 'low':
        scale = PROTO_EE / (ee_topdown + ee_build)   # use the prototype's lower count
        floor_ms, handoff_ms, thr, host_ms, rate_f = 0.10, 0.05, 13, 5.0, lowrate
        linev = 1.00
    else:
        scale = 1.0
        floor_ms, handoff_ms, thr, host_ms, rate_f = 0.35, 0.40, 10, 16.0, highrate
        linev = 1.14       # K1b: line-value arithmetic is 14% of slot 14's time (README K1b: 2.0 of 14.1 ms), taken as an add-on
    tot = dict(bulk=0.0, floors=0.0, build=0.0, handoff=0.0, host=host_ms)
    dev_rounds = 0
    for k in layers:
        e = EE_PAIR_LEAFLAYER if k == 24 else EE_PAIR_GENERIC
        for j in range(k):
            pairs = 2 ** (k - 1 - j)
            if pairs < 2 ** thr:
                break                      # rounds below the threshold run on the host (tail budget, metal.rs:4618, 4761)
            dev_rounds += 1
            comp = pairs * e * scale * rate_f(pairs) * 1e-12 * linev
            byt = pairs * BYTES_PER_PAIR / BW
            t = max(comp, byt, floor_ms * 1e-3) if case == 'low' else max(comp + 0.0, byt, floor_ms * 1e-3) + (byt if comp < byt else 0.0) * 0
            if case == 'high':   # no overlap of loads with arithmetic: add the byte time on top of the arithmetic where both matter
                t = max(comp + byt, floor_ms * 1e-3)
            tot['bulk' if pairs >= 2**15 else 'floors'] += t
        tot['handoff'] += handoff_ms * 1e-3
    # build: one kernel per stored layer (k = 1..23), bulk rate at its size
    for k in range(1, 24):
        nodes = 2 ** k
        if nodes < 2 ** thr:
            continue
        comp = nodes * EE_BUILD_NODE * scale * rate_f(nodes) * 1e-12 * linev
        byt = nodes * 48 / BW
        t = max(comp, byt, floor_ms * 1e-3) if case == 'low' else max(comp + byt, floor_ms * 1e-3)
        tot['build'] += t
    tot['host'] *= 1e-3
    return tot, dev_rounds

# ---- 2b. layer table ---------------------------------------------------------------------------------------------
print('\nlayer k: rounds, pairs in round 0, device rounds at the 2^13 and 2^10 host-tail lines, M ee-equivalents (structural), GB moved (180 B per pair)')
for k in layers:
    e = EE_PAIR_LEAFLAYER if k == 24 else EE_PAIR_GENERIC
    d13 = max(0, k - 13); d10 = max(0, k - 10)
    print('  k=%2d rounds %2d pairs0 2^%-2d dev13 %2d dev10 %2d ee %.2f M  GB %.3f' % (k, k, k - 1, d13, d10, e * 2**k / 1e6, 2**k * BYTES_PER_PAIR / 1e9))
print('  device rounds at the 2^13 line: %d, at the 2^10 line: %d; rounds in all: %d' % (sum(max(0, k - 13) for k in layers), sum(max(0, k - 10) for k in layers), sum(layers)))

# ---- 2c. absolute floor: K4 independent-chain ee rate everywhere, prototype ee count, loads fully hidden, no hand-off and no host tail
K4_PS = 23.49
def floor_with(round_floor_s):
    fl = 0.0
    for k in layers:
        for j in range(k):
            pairs = 2 ** (k - 1 - j)
            if pairs < 2 ** 13: break
            e = EE_PAIR_LEAFLAYER if k == 24 else EE_PAIR_GENERIC
            fl += max(pairs * e * (PROTO_EE / (ee_topdown + ee_build)) * K4_PS * 1e-12, pairs * BYTES_PER_PAIR / BW, round_floor_s)
    for k in range(1, 24):
        if 2 ** k < 2 ** 13: continue
        fl += max(2**k * EE_BUILD_NODE * (PROTO_EE / (ee_topdown + ee_build)) * K4_PS * 1e-12, 2**k * 48 / BW, round_floor_s)
    return fl
fl = floor_with(0.10e-3)
print('absolute floor with a 0.057 ms round (the fast transcript step alone at c1, K9 v3: 56.8 us; eval, reduce and fold not counted): %.2f ms' % (floor_with(0.057e-3) * 1e3))
print('absolute floor with a 0.123 ms round (the shipped transcript step alone, K9): %.2f ms' % (floor_with(0.123e-3) * 1e3))
FLOOR = fl
print('\nabsolute floor (K4 rate 23.49 ps per ee everywhere, prototype ee count, loads hidden, floor 0.10 ms a round, no hand-off, no host tail): %.2f ms' % (fl * 1e3))

for case in ('low', 'high'):
    t, n = tree_time(case)
    s = sum(t.values())
    print('\n%s bound: device rounds %d; ms: bulk (pairs>=2^15) %.2f, mid/small device rounds %.2f, build %.2f, layer hand-offs %.2f, host tail %.2f; TOTAL %.2f ms' % (
        case, n, t['bulk']*1e3, t['floors']*1e3, t['build']*1e3, t['handoff']*1e3, t['host']*1e3, s*1e3))
    if case == 'low': LOW = s
    else: HIGH = s

# ---- 3. what A saves per block (device ms, one lane) ------------------------------------------------------------
CAD = 3745.5; B32 = 32
sav_t52 = [s * CAD / B32 for s in (0.098, 0.103)]       # rule of tick 22: x ms per block = x*32/3745.5 of cadence, full pass-through
print('\nA saves per block, from tick 52 (9.8 to 10.3 percent of the 3.7455 s cadence, rule of tick 22): %.2f to %.2f ms' % tuple(sav_t52))
# cross-check from tick 40's app-profile slot times: H commit 12.68 ms of 2,606 rows -> 6 rows left; A commit 12.21 ms per 2,504 rows grows by 0 to 124 rows
h_save = 12.68 * (1 - 6 / 2606)
a_cost = (0, 12.21 / 2504 * 124)
print('cross-check, commits only (tick 40, one lane): H commit saved %.2f ms, A commit grows by %.2f to %.2f ms: net %.2f to %.2f ms' % (
    h_save, a_cost[0], a_cost[1], h_save - a_cost[1], h_save - a_cost[0]))
# terms tick 52 left out: helper tables inside the five domain zero-checks and the table-helper slot, and the H opening fold
slots = {'D slot 14': (16.31, 10, 37), 'Q slot 15': (5.68, 3, 15), 'Kv slot 16': (3.05, 3, 15), 'S slot 17': (7.63, 4, 19), 'F slot 18': (21.42, 4, 19)}
lin = sum(ms * h / t for ms, h, t in slots.values())
tot_ms = sum(v[0] for v in slots.values())
print('slots 14 to 18: %.2f ms one lane; helper tables are 24 of 105 live tables; table-linear share %.2f ms (upper); K1 load share (0.11 to 0.19 of the kernel) x 24/105 = %.2f to %.2f ms (lower)' % (
    tot_ms, lin, tot_ms * 0.11 * 24/105, tot_ms * 0.19 * 24/105))
extra_lo = tot_ms * 0.11 * 24/105
extra_hi = lin + 4.03 + 12.68/2606*0 + 4.18*2606/2504   # + slot 19 whole (4.03) + H opening fold, scaled from spfold 2504 rows (4.18 ms)
print('terms tick 52 did not count (upper = table-linear + slot 19 whole + H opening fold %.2f ms) : %.2f to %.2f ms' % (4.18*2606/2504, extra_lo, extra_hi))

print('low bound without its two ASSUMED terms (hand-offs, host tail): %.2f ms' % (LOW*1e3 - 5.0 - 1.2))
print('\nPASS line (high < half of saving, tick 52 basis): %.2f ms; high bound %.2f ms -> %s' % (sav_t52[0]/2, HIGH*1e3, 'pass' if HIGH*1e3 < sav_t52[0]/2 else 'not passed'))
print('KILL line (low > saving, tick 52 basis): %.2f ms; low bound %.2f ms -> %s' % (sav_t52[1], LOW*1e3, 'KILL' if LOW*1e3 > sav_t52[1] else 'not killed'))
print('absolute floor %.2f ms against the same saving %.2f to %.2f ms' % (FLOOR*1e3, sav_t52[0], sav_t52[1]))
print('best case of the left-out-terms comparison: gross saving high 33.3 - low tree %.1f - leaf claim 9.4 = %.1f ms = %.2f percent of cadence at full pass-through (rule of tick 22)' % (LOW*1e3, 33.3 - LOW*1e3 - 9.4, (33.3 - LOW*1e3 - 9.4) * 32 / 3745.5 * 100))
gross_lo = h_save - a_cost[1] + extra_lo
gross_hi = h_save - a_cost[0] + extra_hi
print('with the left-out terms the gross saving is %.1f to %.1f ms; tree + leaf-claim terms (6a ESTIMATE 9.4 ms Metal, carried) + M rows (carried 8.6 to 25.9 ms, off the critical path if M is committed early):' % (gross_lo, gross_hi))
for lab, tr in (('low', LOW*1e3), ('high', HIGH*1e3)):
    print('  %s tree %.1f ms; with leaf-claim 9.4: %.1f; net against gross saving range: %.1f to %.1f ms' % (lab, tr, tr + 9.4, gross_lo - (tr + 9.4), gross_hi - (tr + 9.4)))
