import sys, collections
sys.dont_write_bytecode=True
sys.path.insert(0,"/Users/victorrielly/IntelligenceRegulation/results/zk60_claude_batch8_sealing_split_20261117")
import sampleparse as sp
th=sp.parse(sys.argv[1]); want=sys.argv[2]
cnt=collections.Counter()
for h,t,ss in th:
    for st,c in ss:
        names=[n for n,o in st]
        if not any(n.endswith("trained_block::witness_for_block") for n in names): continue
        j=[i for i,n in enumerate(names) if n.endswith(want)]
        if not j: continue
        tail=[n.split("::")[-1][:32] for n in names[j[0]+1:]]
        cnt[" > ".join(tail[:7])]+=c
for k,c in cnt.most_common(25): print(c,k)
