"""Batch 8: what the SealPool workers (hl-seal8-N) do: working samples by the first hashline frame of the job and its second frame."""
import sys, collections, json
sys.dont_write_bytecode=True
sys.path.insert(0,"/Users/victorrielly/IntelligenceRegulation/results/zk60_claude_batch8_sealing_split_20261117")
import sampleparse as sp
SL=("__psynch_cvwait","__ulock_wait","__psynch_mutexwait","semaphore_wait","__semwait","mach_msg","kevent","swtch_pri","thread_switch","sched_yield")
out={}
for path,lab in ((sys.argv[1],"s1"),(sys.argv[2],"s2")):
    cnt=collections.Counter(); tot=0
    for h,t,ss in sp.parse(path):
        if "hl-seal8-" not in h: continue
        for st,c in ss:
            names=[n for n,o in st]
            if st[-1][0].startswith(SL): continue
            if any("wait_done" in n for n in names): cnt["(device wait spin in a product)"]+=c; tot+=c; continue
            if any(n.endswith("trained_block::witness_for_block") for n in names):
                cnt["(main line, see split)"]+=c; tot+=c; continue
            proj=[n.replace("hashline::private_block::","") for n in names if n.startswith("hashline::")]
            cnt[" > ".join(p[:38] for p in proj[:2]) if proj else "(no hashline frame) "+names[-1][:36]]+=c; tot+=c
    out[lab]={"total_working":tot,"top":cnt.most_common(14)}
    print(lab,tot)
    for k,c in cnt.most_common(14): print("  ",c,k)
json.dump(out,open("/Users/victorrielly/IntelligenceRegulation/results/zk60_claude_batch8_sealing_split_20261117/worker_jobs.json","w"),indent=1)
