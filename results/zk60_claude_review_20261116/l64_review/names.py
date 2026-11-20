import re,glob,os
B='/Users/victorrielly/IntelligenceRegulation/formal/ZK60Formal/'
mine=['RunBlkAliveR13']
pat=re.compile(r'^(?:@\[[^\]]*\]\s*)?(?:private\s+|protected\s+)?(?:noncomputable\s+)?(?:theorem|lemma|def|abbrev|structure|instance|inductive|class)\s+([^\s({:\[]+)',re.M)
def decls(p):
    t=open(p).read()
    # track namespace crudely: collect plain names
    return [(m.group(1)) for m in pat.finditer(t)]
d={}
for f in mine:
    d[f]=decls(B+f+'.lean')
others={}
for p in glob.glob(B+'*.lean'):
    n=os.path.basename(p)[:-5]
    if n in mine: continue
    for x in decls(p): others.setdefault(x,[]).append(n)
tot=0
for f in mine:
    print(f,len(d[f]))
    for x in d[f]:
        tot+=1
        if x in others: print('  CLASH-by-short-name',x,others[x][:5])
# duplicates within mine
allm=[x for f in mine for x in d[f]]
import collections
for k,v in collections.Counter(allm).items():
    if v>1: print('dup within L65',k,v)
print('total',tot)
