import re, sys
from collections import Counter
std = frozenset(['propext', 'Classical.choice', 'Quot.sound'])
for out, decls in (('inst_elab.out', 'RunShieldInstP_decls.txt'), ('lu_elab.out', 'RunStgShieldLu_decls.txt')):
    T = open(out).read()
    T = re.sub(r'\n\s+', ' ', T)
    ax = {}; nodep = []; other = []
    for l in T.split('\n'):
        if not l.strip(): continue
        m = re.match(r"'(.+)' depends on axioms: \[(.*)\]\s*$", l)
        if m: ax[m.group(1)] = frozenset(x.strip() for x in m.group(2).split(','))
        elif 'does not depend' in l: nodep.append(l)
        else: other.append(l)
    print('==', out)
    print('lines with axioms:', len(ax), 'no-axiom lines:', len(nodep), 'other lines:', len(other))
    for l in other[:10]: print('   OTHER:', l[:250])
    print('outside standard set:', [k for k, v in ax.items() if not v <= std])
    print('any sorryAx / ofReduceBool:', any('sorryAx' in v or 'Lean.ofReduceBool' in v for v in ax.values()))
    print(Counter(tuple(sorted(v)) for v in ax.values()))
    items = [l.split(' ', 3) for l in open(decls).read().split('\n') if l]
    names = [(x[3] if x[2] == 'PRIVATE' else x[2], x[1], x[2] == 'PRIVATE') for x in items]
    printed = sum(1 for n, k, p in names if n in ax or any(("'%s'" % n) in s for s in nodep))
    print('declarations in source:', len(names), 'printed:', printed, 'public:', sum(1 for n, k, p in names if not p),
          'public theorems:', sum(1 for n, k, p in names if not p and k in ('theorem', 'lemma')))
    print('every public decl printed and standard:', all((n in ax and ax[n] <= std) or any(("'%s'" % n) in s for s in nodep) for n, k, p in names if not p))
    for t in ('ZK60.ProtocolClassify.sshC_productionReadyL_epP_shieldInst', 'ZK60.ProtocolClassify.stgLkIn_rbr', 'ZK60.ProtocolClassify.stgLkOut_rbr', 'ZK60.ProtocolClassify.shd_hLuStg', 'ZK60.ProtocolClassify.shdP_rtProf_valid'):
        if t in ax: print('AX', t, sorted(ax[t]))
