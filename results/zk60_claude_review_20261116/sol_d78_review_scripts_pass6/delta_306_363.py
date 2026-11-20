"""Pass-6: unified diff of source-d78-306 vs source-d78-363 (hashline/src), plus whether the cfg(test) gate is kept (read-only)."""
import os, difflib
B = '/Users/victorrielly/IntelligenceRegulation/results/zk60_sol_20261105_w16r3/b3/'
a, b = B + 'source-d78-306/hashline/', B + 'source-d78-363/hashline/'
n = 0
for dp, _, fs in os.walk(b):
    for f in fs:
        pb = os.path.join(dp, f); rel = os.path.relpath(pb, b); pa = a + rel
        if not os.path.exists(pa): print('NEW', rel); continue
        x, y = open(pa, errors='replace').read().splitlines(), open(pb, errors='replace').read().splitlines()
        if x != y:
            print('=== CHANGED', rel)
            for l in difflib.unified_diff(x, y, lineterm='', n=1):
                n += 1
                if n < 120: print(l[:220])
print('diff lines', n)
