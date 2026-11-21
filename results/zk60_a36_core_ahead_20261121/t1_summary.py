#!/usr/bin/env python3
"""T1 summary: reads raw/t1/t1_results.json (and raw/t1.guard.json) and prints the legs' values, medians, ratios and the verdict by the pre-registered rule."""
import json
from pathlib import Path

d = Path(__file__).resolve().parent / 'raw'
r = json.load(open(d / 't1' / 't1_results.json'))
for l in r['legs']:
    t = [q for q in l['requests'] if not q['warmup']]
    u = [x[1] for x in l['gpu_util_samples']]
    print('leg', l['leg'], 'A36', l['A36'], 'startup_s', round(l['startup_s'], 1))
    print('  warm-up prove', l['requests'][0]['prove_seconds'], '| timed prove', [q['prove_seconds'] for q in t], '| median', l['median_prove_seconds'])
    print('  timed request wall', [round(q['wall_s'], 3) for q in t], '| median', round(l['median_wall_s'], 3))
    print('  ds4-bench before/after', l['ds4_bench_before'].strip(), '/', l['ds4_bench_after'].strip(), '| ioreg util before', l['gpu_util_before'], '| samples', len(u), 'max', max(u) if u else None, 'mean', round(sum(u) / len(u), 1) if u else None)
    s = t[0]['segment_elapsed']
    print('  segments (r1)', len(s), 'first', s[:2], 'last', s[-2:], '| receipt bytes', t[0]['receipt_bytes'])
    if 'verified' in l:
        print('  verified', [v['status'] for v in l['verified']])
m = r['medians']
p1, p2 = m[1] / m[0], m[2] / m[3]
ok = all(v['status'] == 'checked' for l in r['legs'] if l['A36'] for v in l.get('verified', [])) and sum(len(l.get('verified', [])) for l in r['legs'] if l['A36']) == 8
print('medians', m, 'ratios on/off', round(p1, 4), round(p2, 4), 'reductions %', round(100 * (1 - p1), 2), round(100 * (1 - p2), 2))
print('all 8 on-leg receipts checked:', ok)
print('VERDICT:', 'PASS' if (p1 <= 0.96 and p2 <= 0.96 and ok) else 'KILL')
