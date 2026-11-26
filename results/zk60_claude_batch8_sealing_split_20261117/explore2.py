import sys, collections
sys.dont_write_bytecode=True
sys.path.insert(0,"/Users/victorrielly/IntelligenceRegulation/results/zk60_claude_batch8_sealing_split_20261117")
import sampleparse as sp
th=sp.parse(sys.argv[1])
# call-site offsets of build_with: callee name below it, in stacks of the pool main line
cnt=collections.Counter()
for h,t,ss in th:
    for st,c in ss:
        names=[n for n,o in st]
        if not any(n.endswith("trained_block::witness_for_block") for n in names): continue
        for i,(n,o) in enumerate(st):
            if n.endswith("accuracy::build_with") and i+1<len(st):
                cnt[(o,st[i+1][0].split("::")[-1][:40], st[i+2][0].split("::")[-1][:30] if i+2<len(st) else "")]+=c
                break
for k,c in sorted(cnt.items()): print(k,c)
