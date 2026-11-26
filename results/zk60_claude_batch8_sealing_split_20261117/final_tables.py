import json, statistics as st, sys
sys.dont_write_bytecode=True
from pathlib import Path
OUT=Path(__file__).resolve().parent
M=json.loads((OUT/"BATCH8_METRICS.json").read_text())
ref=M["arms"]["A_default_view"]["seal_pass_s"]["median"]
runs={}
for lab in ("s1_sampled","s2_sampled"):
    runs[lab]=json.loads((OUT/f"{lab}.split.json").read_text())
cats={}
for lab,d in runs.items():
    tot=d["main_line_total_samples"]
    for k,v in d["categories"].items(): cats.setdefault(k,[]).append(v["samples"]/tot)
    for k,v in d["groups"].items(): cats.setdefault("GROUP_"+k,[]).append(v["samples"]/tot)
sub={
 "a_cs3_total":[k for k in cats if k.startswith("a_cs3")],
 "a_assign_total":["a_assign_alloc_zero","a_assign_limb_loops"],
 "a_padded_true_other_lane":["a_padded_plane","a_true_words","a_true_words_or_padded_inlined","x_lane_other"],
}
def share(keys,i): return sum(cats[k][i] for k in keys if k in cats and len(cats[k])>i)
res={"unsampled_reference_seal_pass_s":ref,"note":"seconds = share of main line (mean of the two sampled runs) x the unsampled reference pass (A arm median, n=12)"}
rows={}
for k,v in sorted(cats.items()):
    sh=st.mean(v); rows[k]={"share_run1":v[0],"share_run2":v[1] if len(v)>1 else None,"share_mean":sh,"s_per_pass_at_unsampled_scale":sh*ref}
for name,keys in sub.items():
    v=[share(keys,0),share(keys,1)]; rows[name]={"share_run1":v[0],"share_run2":v[1],"share_mean":st.mean(v),"s_per_pass_at_unsampled_scale":st.mean(v)*ref}
res["rows"]=rows
# sampled-wall figures
res["sampled_runs"]={lab:{"sealing_walls_s":[p["sealing_wall_s_sampled_run"] for p in d["passes"]],"seal_chain_samples":[p["seal_chain_samples"] for p in d["passes"]],"ms_per_sample":d["sec_per_sample"]*1000,
   "main_line_total_s_per_pass":d["main_line_total_s_per_pass_sampled"],"in_pool_samples":d["pool_main_line_samples"],"lane_wait_samples":d["lane_wait_on_pool_samples"],
   "avg_workers_working":d["avg_workers_working_during_sealing"],"avg_workers_working_plus_device_spin":d["avg_workers_working_plus_device_wait"],
   "group_s_per_pass_sampled":{g:v["s_per_pass_sampled"] for g,v in d["groups"].items()}} for lab,d in runs.items()}
M["q1_split"]=res
(OUT/"BATCH8_METRICS.json").write_text(json.dumps(M,indent=1)+"\n")
for k,v in rows.items():
    print(f"{k:42s} share {100*v['share_mean']:5.1f}% ({100*v['share_run1']:.1f}/{100*(v['share_run2'] or 0):.1f})  {v['s_per_pass_at_unsampled_scale']:.3f} s/pass  {1000*v['s_per_pass_at_unsampled_scale']/32:.1f} ms/block")
print(json.dumps(res["sampled_runs"],indent=1)[:1500])
