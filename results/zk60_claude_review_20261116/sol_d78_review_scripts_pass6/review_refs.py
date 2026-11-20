"""Pass-6 A: compare reviewer-reference pins in 385 with the live review files; list which review files are/aren't pinned."""
import json, hashlib, os
R = '/Users/victorrielly/IntelligenceRegulation'
B = R + '/results/zk60_sol_20261105_w16r3/b3'
D = R + '/results/zk60_claude_review_20261116'
pins = json.load(open(B + '/D78_INDEPENDENT_INTEGRATION_REVIEW_385.json'))['pins']
sha = lambda p: hashlib.sha256(open(p, 'rb').read()).hexdigest()
live = {f: sha(D + '/' + f) for f in os.listdir(D) if f.startswith('SOL_D78_REVIEW')}
pinned = {k: v for k, v in pins.items() if 'REVIEW' in k and k.endswith('.md')}
for k, v in pinned.items():
    base = os.path.basename(k).replace('_REFERENCE_371', '').replace('_229_PASS2', '_229_LATEST')
    print(k, v[:12], 'live', live.get(base, '?')[:12], 'EQ' if live.get(base) == v else 'DIFF')
for f, h in live.items():
    print('live file', f, h[:12], 'pinned-by-hash' if h in pins.values() else 'NOT PINNED (by hash)')
# also any pin for pass-6 style scripts dirs
for k in pins:
    if 'review_scripts' in k or 'zk60_claude' in k:
        print('script/review pin', k)
