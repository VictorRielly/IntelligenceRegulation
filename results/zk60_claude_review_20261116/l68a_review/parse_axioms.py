import re
from collections import Counter
D = '/Users/victorrielly/IntelligenceRegulation/results/zk60_claude_review_20261116/l68a_review/'
std = frozenset(['propext', 'Classical.choice', 'Quot.sound'])
T = open(D + 'blk_elab.out').read()
T = re.sub(r'\n\s+', ' ', T)
ax = {}; nodep = {}; other = []
for l in T.split('\n'):
    if not l.strip(): continue
    m = re.match(r"'(.+)' depends on axioms: \[(.*)\]\s*$", l)
    m2 = re.match(r"'(.+)' does not depend on any axioms", l)
    if m: ax[m.group(1)] = frozenset(x.strip() for x in m.group(2).split(','))
    elif m2: nodep[m2.group(1)] = True
    else: other.append(l)
def short(n):
    return n.split('RunShieldBlkInst_review_copy.0.')[-1]
allk = {short(k): v for k, v in ax.items()}
for k in nodep: allk[short(k)] = frozenset()
items = [l.split(' ', 3) for l in open(D + 'RunShieldBlkInst_decls.txt').read().split('\n') if l]
names = [(x[3] if x[2] == 'PRIVATE' else x[2], x[1], x[2] == 'PRIVATE') for x in items]
print('declarations in source:', len(names), 'public', sum(1 for n, k, p in names if not p), 'private', sum(1 for n, k, p in names if p))
print('public theorems', sum(1 for n, k, p in names if not p and k in ('theorem', 'lemma')), 'public defs/abbrev/instance', sum(1 for n, k, p in names if not p and k not in ('theorem', 'lemma')))
missing = [n for n, k, p in names if n not in allk]
print('declarations without a printed axiom line:', missing)
print('printed axiom lines (source decls):', sum(1 for n, k, p in names if n in allk))
print('outside standard set:', [k for k, v in allk.items() if not v <= std])
print('any sorryAx/ofReduceBool:', any('sorryAx' in v or 'Lean.ofReduceBool' in v for v in allk.values()))
print('distribution over source decls:', Counter(tuple(sorted(allk[n])) for n, k, p in names if n in allk))
print('non-axiom message lines (first 15):')
for l in other[:15]: print('   ', l[:200])
for n, k, p in names:
    if not p: print('PUB', k, n, sorted(allk.get(n, ['?'])))
