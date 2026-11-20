"""Pass-6 C: summarise D78_ACTUAL_COMPACT_M_RANK_374.json and recount rows/controls (read-only)."""
import json
B = '/Users/victorrielly/IntelligenceRegulation/results/zk60_sol_20261105_w16r3/b3/'
d = json.load(open(B + 'D78_ACTUAL_COMPACT_M_RANK_374.json'))
print({k: (v if not isinstance(v, (dict, list, str)) or len(json.dumps(v)) < 200 else '...') for k, v in d.items() if k not in ('pins',)})
rows = ctrl = 0
for mode, st in d['actual_stages_by_mode'].items():
    for s in st:
        c = s['controls']
        n = 2 + len(c['minor_premise_controls_refused'])
        rows += s['rank_fp2']; ctrl += n
        print(mode, s['stage'], s['kind'], {k: v for k, v in s.items() if k not in ('constructive_minor', 'controls', 'stage', 'kind')},
              'controls', n, [x['reason'] for x in c['minor_premise_controls_refused']], c['duplicate_functional_rank'], c['zero_first_functional_rank'])
        cm = s['constructive_minor']
        print('   minor keys', {k: (v if len(json.dumps(v)) < 80 else '..') for k, v in cm.items()})
print('rows', rows, 'controls', ctrl)
for p in d['actual_SS_mask_reuse_projections']:
    print('SS projection', p)
print('pins', len(d['pins']))
