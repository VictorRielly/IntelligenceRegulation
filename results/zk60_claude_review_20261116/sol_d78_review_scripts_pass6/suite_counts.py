"""Pass-6 B: recount the 365 full-suite log and registries from retained files (read-only)."""
import re, collections, json
D = '/Users/victorrielly/IntelligenceRegulation/results/zk60_sol_20261105_w16r3/b3/d78-census-validation365/'
log = open(D + 'full.native.log', errors='replace').read().splitlines()
c = collections.Counter()
names = {}
for l in log:
    m = re.match(r'^test (\S+) \.\.\. (ok|FAILED|ignored.*)$', l)
    if m:
        st = m.group(2).split(',')[0].split(' ')[0]
        c[st] += 1; names[m.group(1)] = st
print('per-test lines in log:', dict(c), 'total', sum(c.values()), 'distinct names', len(names))
reg = [l for l in open(D + 'registry.txt').read().splitlines() if l.endswith(': test')]
print('registry.txt test lines', len(reg), 'distinct', len(set(reg)))
ig = open(D + 'ignored-registry.txt').read().splitlines()
print('ignored-registry.txt lines', len(ig), ig[:3])
igt = [l for l in ig if l.endswith(': test')]
print('ignored-registry test lines', len(igt))
# names in registry vs log
rn = set(l[:-len(': test')] for l in reg)
print('registry names - log names', len(rn - set(names)), 'log names - registry', len(set(names) - rn))
ign_log = {n for n, s in names.items() if s.startswith('ignored')}
ign_reg = set(l[:-len(': test')] for l in igt)
print('ignored in log', len(ign_log), 'ignored in ignored-registry', len(ign_reg), 'equal', ign_log == ign_reg)
# ignore reasons
reasons = collections.Counter()
for l in log:
    m = re.match(r'^test (\S+) \.\.\. ignored, (.*)$', l)
    if m: reasons[m.group(2)[:90]] += 1
print('ignore reasons (top)', reasons.most_common(8))
print('log 177 ignored with reason', sum(reasons.values()))
for f in ('full.qualification.json',):
    q = json.load(open(D + f))
    print(f, {k: (str(v)[:150]) for k, v in q.items() if k != 'registry'})
