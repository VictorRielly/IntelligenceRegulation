"""Pass-6 B: compare per_replay_mode in 385 with the retained replay qualification files; recompute segment byte sum (read-only)."""
import json, os
B = '/Users/victorrielly/IntelligenceRegulation/results/zk60_sol_20261105_w16r3/b3/'
V = B + 'd78-census-validation365/'
pkg = json.load(open(B + 'D78_INDEPENDENT_INTEGRATION_REVIEW_385.json'))
for mode in ('outer', 'scaled'):
    q = json.load(open(V + f'replay/{mode}.qualification.json'))
    print('==', mode, 'keys', list(q)[:40])
    for k, v in q.items():
        s = json.dumps(v)
        if k in ('pins',): continue
        print('  ', k, s[:260])
    print('  PKG', json.dumps(pkg['per_replay_mode'][mode])[:300])
    rec = V + ('outer-receipt' if mode == 'outer' else 'scaled-receipt')
    print('  segment bytes sum', sum(os.path.getsize(rec + f'/segment_00{i}.bin') for i in range(4)))
    print(open(V + f'replay/{mode}.progress.jsonl').read()[:1800])
