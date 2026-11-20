import re
T=open('l66_elab.out').read()
T=re.sub(r'\n\s+',' ',T)   # join wrapped continuation lines
L=T.split('\n')
ax={}; nodep=[]
other=[]
for l in L:
    if not l.strip(): continue
    m=re.match(r"'(.+)' depends on axioms: \[(.*)\]\s*$",l)
    if m: ax[m.group(1)]=frozenset(x.strip() for x in m.group(2).split(','))
    elif 'does not depend' in l: nodep.append(l)
    else: other.append(l)
std=frozenset(['propext','Classical.choice','Quot.sound'])
print('lines with axioms:',len(ax),'no-axiom lines:',len(nodep),'other lines (errors/warnings/info):',len(other))
for l in other[:10]: print('   OTHER:',l[:250])
print('outside standard set:',[k for k,v in ax.items() if not v<=std])
print('any sorryAx / ofReduceBool:',any('sorryAx' in v or 'Lean.ofReduceBool' in v for v in ax.values()))
from collections import Counter
print(Counter(tuple(sorted(v)) for v in ax.values()))
items=[l.split(' ',3) for l in open('public_theorems.txt').read().split('\n') if l]
pubn=[x[2] if x[2]!='PRIVATE' else x[3] for x in items if x[1] in('theorem','lemma') and x[2]!='PRIVATE']
print('public theorems per script:',len(pubn))
allthm=[(x[2] if x[2]!='PRIVATE' else x[3]) for x in items if x[1] in('theorem','lemma')]
print('theorems (incl private) printed:',sum(1 for n in allthm if n in ax or any(n in s for s in nodep)),'of',len(allthm))
print('public theorems all printed and standard:',all(n in ax and ax[n]<=std for n in pubn))
top='ZK60.ProtocolClassify.RunShapeP.sshC_productionReadyL_epP_pinsHd'
print('TOP:',sorted(ax[top]))
