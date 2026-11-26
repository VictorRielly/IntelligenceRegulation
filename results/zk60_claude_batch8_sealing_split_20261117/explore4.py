import sys, collections
sys.dont_write_bytecode=True
sys.path.insert(0,"/Users/victorrielly/IntelligenceRegulation/results/zk60_claude_batch8_sealing_split_20261117")
import sampleparse as sp
th=sp.parse(sys.argv[1])
roles=collections.Counter()
for h,t,ss in th:
    nm=h.split(":",1)[-1].strip()[:50] if ":" in h else h[:50]
    seal=sum(c for st,c in ss if any(n.endswith("trained_block::witness_for_block") for n,o in st))
    lane=sum(c for st,c in ss if any(n.endswith("trained_block::seal_chain") for n,o in st))
    load=sum(c for st,c in ss if any("LoadAhead" in n for n,o in st))
    if "hl-seal" in h or seal or lane or load:
        print(t, nm, "| inwfb",seal,"lane",lane,"load",load)
    roles[nm]+=1
print(len(th),"threads")
