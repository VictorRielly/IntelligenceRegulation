import sys, collections
sys.dont_write_bytecode=True
sys.path.insert(0,"/Users/victorrielly/IntelligenceRegulation/results/zk60_claude_batch8_sealing_split_20261117")
import sampleparse as sp
th=sp.parse(sys.argv[1])
cnt=collections.Counter(); tot=collections.Counter()
SL=("__psynch_cvwait","__ulock_wait","__psynch_mutexwait","semaphore_wait","__semwait","mach_msg","kevent","swtch_pri","thread_switch","__workq_kernreturn","_dispatch_sema4")
for h,t,ss in th:
    if "hl-seal8" in h: continue
    for st,c in ss:
        leaf=st[-1][0]
        if leaf.startswith(SL): continue
        names=[n for n,o in st]
        if any("wait_done" in n for n in names): key="DEVICE_WAIT"
        else:
            proj=[n for n in names if n.startswith("hashline::")]
            key=" > ".join(x.replace("hashline::private_block::","")[:40] for x in proj[:3]) if proj else "(no hashline frame) "+names[-1][:40]
        cnt[key]+=c
for k,c in cnt.most_common(40): print(c,k)
