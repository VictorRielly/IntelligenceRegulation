import collections, sys
sys.dont_write_bytecode=True
sys.path.insert(0,"/Users/victorrielly/IntelligenceRegulation/results/zk60_effplan_20261105/a11")
import sample_summary as ss
path=sys.argv[1]; key=sys.argv[2]; depth=int(sys.argv[3])
th=ss.parse(path)
def short(n):
    n=n.replace("hashline::private_block::","").replace("hashline::","")
    return n[:70]
cnt=collections.Counter(); tot=0
for header,nodes in th:
    for st,c in ss.self_samples(nodes):
        idx=[i for i,n in enumerate(st) if key in n]
        if not idx: continue
        i=idx[-1] if len(sys.argv)<5 else idx[0]
        tail=[short(n) for n in st[i+1:i+1+depth]]
        cnt[" > ".join(tail) or "(self)"]+=c; tot+=c
print("total samples",tot)
for k,c in cnt.most_common(45): print(c,k)
