import re,difflib
B='/Users/victorrielly/IntelligenceRegulation/formal/ZK60Formal/'
def sig(path,name):
    t=open(B+path).read()
    i=t.index('theorem '+name+'\n')
    j=t.index(':=',t.index('ProductionReadyL (classifyModelP',i))
    return t[i:j]
old=sig('RunStgShieldCTopW.lean','sshC_productionReadyL_epP_claimsW')
new=sig('RunStgShieldCTopDg.lean','sshC_productionReadyL_epP_dg')
def binders(s):
    # split top-level lines starting with '    ('
    return [l.rstrip() for l in s.split('\n')]
o=binders(old);n=binders(new)
for l in difflib.unified_diff(o,n,lineterm='',n=0):
    print(l[:600])
print("=== after substituting dgI/dgO")
import re
o2=old.replace('    (dgI dgO : ℕ → ℕ)\n','')
o2=re.sub(r'\bdgI\b','ZK60.ProtocolClassify.sshDgI',o2)
o2=re.sub(r'\bdgO\b','ZK60.ProtocolClassify.sshDgO',o2)
o2=o2.replace('claimsW','dg')
print(o2==new)
for l in difflib.unified_diff(o2.split('\n'),new.split('\n'),lineterm='',n=0): print(l[:300])
print(old.count('dgI'),old.count('dgO'))
