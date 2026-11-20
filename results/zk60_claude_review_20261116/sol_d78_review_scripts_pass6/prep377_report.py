"""Pass-6 D: summarise 377 (the preparation behind 376) and its controls (read-only)."""
import json
B = '/Users/victorrielly/IntelligenceRegulation/results/zk60_sol_20261105_w16r3/b3/'
d = json.load(open(B + 'D78_SYNTHETIC_TIED_IDENTITY_PREPARATION_377.json'))
print({k: (v if len(json.dumps(v)) < 400 else '...') for k, v in d.items() if k != 'pins'})
print('controls', len(d['controls_refused']), d['controls_refused'])
print('pins', len(d['pins']))
