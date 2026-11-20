"""Pass-6: print structure of package 385 (read-only, stdout). Truncates long values."""
import json, sys
p = '/Users/victorrielly/IntelligenceRegulation/results/zk60_sol_20261105_w16r3/b3/D78_INDEPENDENT_INTEGRATION_REVIEW_385.json'
d = json.load(open(p))
def show(o, depth=0, maxd=2, key=''):
    pad = '  ' * depth
    if isinstance(o, dict):
        print(f'{pad}{key} dict[{len(o)}]')
        if depth < maxd:
            for k, v in o.items():
                show(v, depth + 1, maxd, k)
    elif isinstance(o, list):
        print(f'{pad}{key} list[{len(o)}]')
        if depth < maxd:
            for i, v in enumerate(o[:3]):
                show(v, depth + 1, maxd, f'[{i}]')
    else:
        s = json.dumps(o)
        print(f'{pad}{key}: {s[:int(sys.argv[1]) if len(sys.argv) > 1 else 300]}')
show(d, 0, 2)
