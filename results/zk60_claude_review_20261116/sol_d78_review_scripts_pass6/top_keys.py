"""Pass-6: top-level keys of package 385 with value type and short repr (read-only, stdout)."""
import json, sys
p = '/Users/victorrielly/IntelligenceRegulation/results/zk60_sol_20261105_w16r3/b3/D78_INDEPENDENT_INTEGRATION_REVIEW_385.json'
d = json.load(open(p))
n = int(sys.argv[1]) if len(sys.argv) > 1 else 400
keys = sys.argv[2:]
for k, v in d.items():
    if k == 'pins':
        print(k, type(v).__name__, len(v)); continue
    if keys and k not in keys:
        print(k, type(v).__name__, (len(v) if hasattr(v,'__len__') else ''))
        continue
    print('##', k, json.dumps(v)[:n])
