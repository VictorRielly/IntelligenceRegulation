import re,sys
sys.path.insert(0,'/Users/victorrielly/IntelligenceRegulation/results/zk60_claude_review_20261116/l64_review')
B='/Users/victorrielly/IntelligenceRegulation/formal/ZK60Formal/'
def sig(path,name,concl='ProductionReadyL'):
    t=open(B+path).read()
    i=t.index('theorem '+name)
    j=t.index(':=',t.index(concl,i))
    return t[i+len('theorem '+name):j]
def split_binders(s):
    out=[];i=0;n=len(s)
    while i<n:
        c=s[i]
        if c in '({[':
            d=0;j=i
            while j<n:
                if s[j] in '({[':d+=1
                elif s[j] in ')}]':d-=1
                if d==0:break
                j+=1
            out.append(s[i:j+1]);i=j+1
        elif c==':':
            return out,s[i:]
        else:i+=1
    return out,''
def bname(b):
    m=re.match(r'[\(\{\[]\s*([^:]+?)\s*:',b)
    return m.group(1) if m else b[:30]
def norm(t): return re.sub(r'\s+',' ',t).strip()
o,oc=split_binders(sig('RunBlkShieldInst.lean','bw_productionReadyL_epP_shield_r13'))
n,nc=split_binders(sig('RunBlkAliveR13.lean','sshC_productionReadyL_epP_blkAlive'))
od={bname(b):norm(b) for b in o}
nd={bname(b):norm(b) for b in n}
print('L62 binders',len(o),'L64 binders',len(n))
print('only in L62:',[k for k in od if k not in nd])
print('only in L64:',[k for k in nd if k not in od])
print('in both, text differs:',[k for k in nd if k in od and od[k]!=nd[k]])
print('L62 conclusion:',norm(oc)[:400])
print('L64 conclusion:',norm(nc)[:400])
