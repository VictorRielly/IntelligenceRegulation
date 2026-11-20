"""Pass-6 D: compare pins of the 378 and 383 identity specs, and the 359 spec (read-only)."""
import json
B = '/Users/victorrielly/IntelligenceRegulation/results/zk60_sol_20261105_w16r3/b3/'
s = {n: json.load(open(B + f)) for n, f in (('359', 'D78_LARGE_IDENTITY_BATCH_359_SPEC.json'), ('378', 'D78_LARGE_IDENTITY_RECOVERY_378_SPEC.json'), ('383', 'D78_LARGE_IDENTITY_RECOVERY_383_SPEC.json'))}
for n, d in s.items():
    print(n, 'keys', list(d)[:25], 'pins', len(d['pins']))
a, b = s['378']['pins'], s['383']['pins']
print('only in 378:', sorted(set(a) - set(b)))
print('only in 383:', sorted(set(b) - set(a)))
print('changed:', sorted(k for k in set(a) & set(b) if a[k] != b[k]))
a2 = s['359']['pins']
print('359 vs 378 only in 359:', len(set(a2) - set(a)), 'only in 378', sorted(set(a) - set(a2))[:20])
print('359 vs 378 changed', sorted(k for k in set(a2) & set(a) if a2[k] != a[k])[:20])
