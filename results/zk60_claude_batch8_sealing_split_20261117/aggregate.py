#!/usr/bin/env python3
"""Batch 8: pooled tables and BATCH8_METRICS.json from <label>.pass.json and <label>.split.json (offline)."""
import json, statistics as st, sys
from pathlib import Path
sys.dont_write_bytecode = True
OUT = Path(__file__).resolve().parent
ARMS = {"A_default_view": ["a1_default", "a2_default"], "B_view0": ["b1_view0", "b2_view0"], "S_sampled_default": ["s1_sampled", "s2_sampled"]}
KEYS = ["seal_pass_s", "request_s", "prove_call_s", "crit_commit_to_start_union_s", "sum_commit_to_start_224_s", "median_commit_to_start_ms_all", "gpu_busy_union_s",
        "p1_qkv_wall_s", "p2_s", "p3_wo_wall_s", "p4_s", "p5_gu_wall_s", "p6_s", "p7_wd_wall_s", "p8_interblock_31_s", "p8_bookends_s", "p8_total_s", "p9_s", "wprod_host_inside_s",
        "chain_faults", "chain_user_s", "chain_sys_s", "request_faults_prev_stream_to_req_line", "request_sys_s_polled", "log_request_sys_s", "log_request_user_s"]
def S(v):
    v = [x for x in v if x is not None]
    if not v: return None
    q = st.quantiles(v, n=4) if len(v) > 1 else [v[0]] * 3
    return {"n": len(v), "median": st.median(v), "mean": st.mean(v), "min": min(v), "max": max(v), "iqr": q[2] - q[0]}
res = {"arms": {}, "runs": {}}
for arm, labs in ARMS.items():
    allp = []
    for lab in labs:
        p = OUT / f"{lab}.pass.json"
        if not p.exists(): continue
        d = json.loads(p.read_text())
        res["runs"][lab] = {"meta": d["meta"], "passes": d["passes"], "median_seal_pass_s": st.median([x["seal_pass_s"] for x in d["passes"]]), "median_request_s": st.median([x["request_s"] for x in d["passes"]])}
        allp += d["passes"]
    if not allp: continue
    arm_d = {k: S([x[k] for x in allp]) for k in KEYS}
    prod = ["Q", "K", "V", "Wo", "Wg", "Wu", "Wd"]
    arm_d["commit_to_start_ms_by_product_median_of_pass_medians"] = {prod[i]: st.median([x["median_commit_to_start_ms_by_product_QKVWoWgWuWd"][i] for x in allp]) for i in range(7)}
    res["arms"][arm] = arm_d
splits = {}
for lab in ("s1_sampled", "s2_sampled"):
    p = OUT / f"{lab}.split.json"
    if p.exists(): splits[lab] = json.loads(p.read_text())
res["sampler_splits"] = {k: {kk: v[kk] for kk in v if kk not in ("workers",)} for k, v in splits.items()}
res["sampler_workers"] = {k: v["workers"] for k, v in splits.items()}
(OUT / "BATCH8_METRICS.json").write_text(json.dumps(res, indent=1) + "\n")
def row(arm, k, f="{:.3f}"):
    d = res["arms"][arm][k]; return f.format(d["median"]) + " (iqr " + f.format(d["iqr"]) + ", n=" + str(d["n"]) + ")"
for arm in res["arms"]:
    print("==", arm)
    for k in KEYS: print(f"  {k}: {row(arm, k, '{:.4g}')}")
    print("  c2s ms by product", {k: round(v, 2) for k, v in res["arms"][arm]["commit_to_start_ms_by_product_median_of_pass_medians"].items()})
