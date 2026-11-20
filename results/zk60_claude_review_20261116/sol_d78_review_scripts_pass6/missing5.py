"""Pass-6 B: the 5 registry tests with no clean 'test X ... ok' line in the 365 full log: find their lines (read-only)."""
import re
D = '/Users/victorrielly/IntelligenceRegulation/results/zk60_sol_20261105_w16r3/b3/d78-census-validation365/'
log = open(D + 'full.native.log', errors='replace').read().splitlines()
done = set()
for l in log:
    m = re.match(r'^test (\S+) \.\.\. (ok|FAILED|ignored.*)$', l)
    if m: done.add(m.group(1))
reg = [l[:-6] for l in open(D + 'registry.txt').read().splitlines() if l.endswith(': test')]
miss = [n for n in reg if n not in done]
print(miss)
for n in miss:
    hits = [(i, l[:160]) for i, l in enumerate(log) if 'test ' + n + ' ' in l or l.startswith('test ' + n)]
    print(n, hits[:2])
