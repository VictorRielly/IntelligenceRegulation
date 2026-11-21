"""Tick 33 (queue item 54): why A36 slowed the full-lanes stream. Standard library only; reads the retained
A36 records (T1, T2 json) and does arithmetic. Run with `python3 -I`. No run, no build.
"""
import json
import statistics as st

R = '/Users/victorrielly/IntelligenceRegulation/results/zk60_a36_core_ahead_20261121/raw/'

# ---------- T1 (one lane): prove call, outside-the-prove-call time, ioreg samples
t1 = json.load(open(R + 't1/t1_results.json'))
print('--- T1, one lane (medians over three timed requests per leg) ---')
one = {}
for L in t1['legs']:
    timed = [r for r in L['requests'] if not r.get('warmup')]
    pv = st.median(r['prove_seconds'] for r in timed)
    out = st.median(r['wall_s'] - r['prove_seconds'] for r in timed)
    s = L['gpu_util_samples']
    proving = [u for _, u in s if u >= 40]
    one.setdefault(L['A36'], []).append((pv, out))
    print('leg %d A36=%d prove %.3f  outside-prove %.3f  ioreg mean over samples %.1f, mean of samples >=40: %.1f'
          % (L['leg'], L['A36'], pv, out, sum(u for _, u in s) / len(s), sum(proving) / len(proving)))
p1 = {k: (st.mean(x[0] for x in v), st.mean(x[1] for x in v)) for k, v in one.items()}
print('one lane: off prove %.3f on prove %.3f (%.2f%%), saving %.1f ms per block of 26; outside-prove off %.3f on %.3f'
      % (p1[0][0], p1[1][0], 100 * (p1[1][0] / p1[0][0] - 1), (p1[0][0] - p1[1][0]) / 26 * 1e3, p1[0][1], p1[1][1]))

# ---------- T2 (six lanes x5, eight lanes x4)
print('--- T2 ---')
res = {}
for name, N, lanes in (('t2_setA', 6, 6), ('t2_setB', 8, 8)):
    d = json.load(open(R + name + '/t2_results.json'))
    agg = {0: [], 1: []}
    for L in d['legs']:
        c = sorted(L['completions'], key=lambda x: x['t_s'])
        timed = c[N:]
        span = c[-1]['t_s'] - c[N - 1]['t_s']
        pv = st.mean(x['prove_s'] for x in timed)
        sv = st.mean(x['served_s'] for x in timed)
        period = span / (48 / lanes)
        wall = c[-1]['t_s']
        busy_total = L['gpu_util_mean'] / 100 * wall
        agg[L['A36']].append((pv, sv - pv, period, L['rate'], L['gpu_util_mean']))
        print('%s leg %d A36=%d rate %.2f prove %.3f outside %.3f lane period %.3f (served %.3f + %.3f) ioreg %.1f%% x leg wall %.0f s = %.1f busy-s (%.2f per request, 54/56 requests)'
              % (name, L['leg'], L['A36'], L['rate'], pv, sv - pv, period, sv, period - sv, L['gpu_util_mean'], wall,
                 busy_total, busy_total / len(c)))
    m = {k: [st.mean(x[i] for x in v) for i in range(5)] for k, v in agg.items()}
    res[name] = m
    print('%s mean off: prove %.3f outside %.3f period %.3f rate %.2f | on: prove %.3f outside %.3f period %.3f rate %.2f'
          % (name, m[0][0], m[0][1], m[0][2], m[0][3], m[1][0], m[1][1], m[1][2], m[1][3]))
    print('   on/off: prove x%.3f  outside x%.3f  period x%.3f  rate x%.3f ; prove +%.0f ms per block of 26'
          % (m[1][0] / m[0][0], m[1][1] / m[0][1], m[1][2] / m[0][2], m[1][3] / m[0][3], (m[1][0] - m[0][0]) / 26 * 1e3))

A = res['t2_setA']
print('--- stretch of the unchanged (off) path from one lane to six: prove x%.3f, outside-prove x%.3f'
      % (A[0][0] / p1[0][0], A[0][1] / p1[0][1]))
print('    on path: prove x%.3f, outside-prove x%.3f (one lane on: %.3f, %.3f)' % (A[1][0] / p1[1][0], A[1][1] / p1[1][1], p1[1][0], p1[1][1]))

# ---------- the swing per block
per_block_saved_1 = (p1[0][0] - p1[1][0]) / 26 * 1e3
per_block_lost_6 = (A[1][0] - A[0][0]) / 26 * 1e3
moved = 53.5 + 6.0   # ms: S1 medians A host 3+12+2+11, A commit 21.5, M 4, plus boundary B_k commit 6 (README s11)
print('--- per block: one lane saves %.1f ms, six lanes lose %.1f ms; moved work about %.1f ms (S1 medians: A 3+12+2+11, A commit 21.5, M 4, B commit 6)'
      % (per_block_saved_1, per_block_lost_6, moved))
print('    realised overlap at one lane %.0f%% of moved; six-lane block %.0f ms off, %.0f ms on; perfect overlap would give %.0f ms, excess %.0f ms = %.1fx the moved work = %.0f%% of the block'
      % (100 * per_block_saved_1 / moved, A[0][0] / 26 * 1e3, A[1][0] / 26 * 1e3, A[0][0] / 26 * 1e3 - moved,
         A[1][0] / 26 * 1e3 - (A[0][0] / 26 * 1e3 - moved), (A[1][0] / 26 * 1e3 - (A[0][0] / 26 * 1e3 - moved)) / moved,
         100 * (A[1][0] - A[0][0]) / A[0][0]))

# ---------- (a) the device bound from solo GPU time
blk = 94.679e-3      # pooled median, installed block fixture (REVIEW.md / zk60_w16r2_shield_block_20261120)
seal_dev = 0.534     # product buffers begin->done per request at the app (tick 30, includes queue waits)
for name, label in (('prove only', 0.0), ('prove + sealing products', seal_dev)):
    D = 26 * blk + label
    print('(a) D = %.3f s (%s); 6D = %.2f s against off lane period %.2f s (%.0f%%); with the app trace union/sum 0.79 (tick 30: 14.1 s union per 6 x 2.97) -> %.2f s (%.0f%%)'
          % (D, name, 6 * D, A[0][2], 100 * 6 * D / A[0][2], 0.79 * 6 * D, 100 * 0.79 * 6 * D / A[0][2]))
print('    one lane: D / period = %.0f%% (prove only, T1 period %.2f s); ioreg reads ~65%% while proving at one lane'
      % (100 * 26 * blk / (p1[0][0] + p1[0][1]), p1[0][0] + p1[0][1]))

# ---------- MODEL: closed queue with the device as one first-come server (as tick 30), calibrated on the T2 off period
def mva(n, z, d):
    q = 0.0
    for k in range(1, n + 1):
        r = d * (1 + q)
        x = k / (z + r)
        q = x * r
    return z + r, x

P_block = A[0][0] / 26      # seconds per block at six lanes, off
print('--- MODEL (closed queue, six lanes, calibrated on the off legs: block %.0f ms) ---' % (P_block * 1e3))
for D_ms in (0.79 * 94.7, 94.7):
    D = D_ms / 1e3
    lo, hi = 0.0, P_block
    for _ in range(60):
        z = (lo + hi) / 2
        p, _x = mva(6, z, D)
        lo, hi = (z, hi) if p < P_block else (lo, z)
    Z = lo
    print(' D=%.1f ms/block: think Z=%.0f ms, device busy %.0f%%' % (D_ms, Z * 1e3, 100 * 6 * D / P_block))
    for h in (17, 60):
        p, _ = mva(6, Z - h / 1e3, D)
        print('    cut host gap by %2d ms -> block %.0f ms (x%.3f)' % (h, p * 1e3, P_block / p))
    for x in (1, 5, 10):
        p, _ = mva(6, Z, D - x / 1e3)
        print('    cut device time by %2d ms -> block %.0f ms (x%.3f)' % (x, p * 1e3, P_block / p))
    p, _ = mva(6, Z + 80 / 1e3, D)
    print('    ADD 80 ms of host gap (A36 six-lane measured excess is +%.0f ms net) -> block %.0f ms (x%.3f)' % (per_block_lost_6, p * 1e3, P_block / p))

# ---------- (c) bounds for the other candidates, on the six-lane period
per = A[0][2]
print('--- (c) six-lane period %.2f s ---' % per)
print('repeated public check (tick 32): 0.223 to 0.358 s solo; stretch x%.2f at six lanes -> %.3f to %.3f s = %.1f%% to %.1f%% of the period, if sealing time passes through 1:1'
      % (A[0][1] / p1[0][1], 0.223 * A[0][1] / p1[0][1], 0.358 * A[0][1] / p1[0][1],
         100 * 0.223 * A[0][1] / p1[0][1] / per, 100 * 0.358 * A[0][1] / p1[0][1] / per))
sink_io = 21.0 - 11.1 * (21.0 / 21.4)   # S1 sink 21 ms; digest 11.1 of 21.4 in tick 31's bench
print('segment writer: the sink is 21 ms a block; its digest is about %.1f ms of that (tick 31 bench ratio), so write+fsync+rename about %.1f ms; per request %.2f s = %.1f%% of the period at one-for-one pass-through; whole sink %.2f s = %.1f%%'
      % (21.0 * 11.1 / 21.4, sink_io, 26 * sink_io / 1e3, 100 * 26 * sink_io / 1e3 / per, 26 * 21.0 / 1e3, 100 * 26 * 21.0 / 1e3 / per))
print('seal-ahead at six lanes: moves %.2f s (tick 30, app) of %.2f s; R13 prior x1.039 on the app period' % (2.93, 19.405))
