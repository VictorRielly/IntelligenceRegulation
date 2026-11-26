#!/usr/bin/env python3
"""Batch 8 Q2 extra: page faults, user and system CPU inside the between-block gaps (Wd done of block k to first QKV begin of block k+1; Batch 7's P8a)
versus the rest of the sealing chain, from the 20 ms counter poll aligned to the GPU trace (same monotonic clock). Counters are interpolated
linearly between polls, so a gap of 36 ms holds about two polls: only the totals over 31 gaps x 6 passes are meaningful."""
import json, statistics as st, sys
sys.dont_write_bytecode=True
from pathlib import Path
OUT=Path(__file__).resolve().parent
sys.path.insert(0,str(OUT))
import analyze_runs as ar
res={}
for arm,labs in (("A_default_view",["a1_default","a2_default"]),("B_view0",["b1_view0","b2_view0"])):
    gf=gu=gs=gw=0.0; cf=cu=cs=cw=0.0; per=[]
    for lab in labs:
        rows=ar.load_trace(ar.ART/f"{lab}.trace.tsv.gz")
        a_rows,h_rows=ar.b7.detect_ah_rows(rows)
        passes=ar.b7.split_stream_trace_into_passes(rows,[1]*7,h_rows)
        ser=ar.Series(ar.OUT/f"{lab}.counters.tsv.gz")
        for p in range(1,7):
            wp=sorted([r for r in passes[p] if r["tag"]=="wprod"],key=lambda r:r["begin"])
            blocks=[wp[7*b:7*b+7] for b in range(32)]
            w0=min(r["begin"] for r in blocks[0][:3]); w1=blocks[31][6]["done"]
            tf,tu,ts=ser.delta(w0,w1)
            f=u=s=0.0; w=0.0
            for b in range(1,32):
                a=blocks[b-1][6]["done"]; c=min(r["begin"] for r in blocks[b][:3])
                d=ser.delta(a,c); f+=d[0]; u+=d[1]; s+=d[2]; w+=c-a
            gf+=f;gu+=u;gs+=s;gw+=w; cf+=tf;cu+=tu;cs+=ts;cw+=w1-w0
            per.append({"label":lab,"pass":p-1,"chain_faults":tf,"gap_faults":f,"chain_sys":ts,"gap_sys":s,"chain_user":tu,"gap_user":u,"gap_wall":w,"chain_wall":w1-w0})
    res[arm]={"n_passes":len(per),"gap_wall_share":gw/cw,"gap_fault_share":gf/cf,"gap_sys_share":gs/cs,"gap_user_share":gu/cu,
       "gap_faults_per_pass":gf/len(per),"gap_sys_s_per_pass":gs/len(per),"gap_user_s_per_pass":gu/len(per),"chain_faults_per_pass":cf/len(per),"chain_sys_s_per_pass":cs/len(per),"chain_user_s_per_pass":cu/len(per),"per_pass":per}
    print(arm,{k:round(v,3) for k,v in res[arm].items() if k!="per_pass" and not isinstance(v,list)})
M=json.loads((OUT/"BATCH8_METRICS.json").read_text()); M["q2_gap_counters"]=res
(OUT/"BATCH8_METRICS.json").write_text(json.dumps(M,indent=1)+"\n")
