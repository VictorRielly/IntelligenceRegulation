#!/usr/bin/env python3
"""Token round 16: the real Shieldstral T128 runs, one row per (category, step), from the guarded logs and their guard
records (r16/logs/real-<step>-<cat>.{log,guard.json}) -> r16/real_runs.json and a printed table. [MEASURED, shared box,
n=1]. Verdicts are printed (public by D38(c)); margins are never logged by the CLI."""
import json, os, sys
L = "/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r16/logs"
OUT = "/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r16/real_runs.json"
rows = []
for cat in ("sexual", "violence", "hate"):
    for step in ("prove", "verify", "owner", "label"):
        g = f"{L}/real-{step}-{cat}.guard.json"
        if not os.path.exists(g):
            continue
        gr = json.load(open(g))
        ev = [json.loads(l) for l in open(f"{L}/real-{step}-{cat}.log") if l.startswith("{\"event\"")]
        last = {e["event"]: e for e in ev}
        r = {"category": cat, "step": step, "exit": gr.get("exit"), "wall_s": round(gr.get("child_wall_seconds") or 0, 1),
             "peak_rss_gib": gr.get("peak_rss_gib"), "peak_cgroup_gib": gr.get("peak_cgroup_gib"), "need_gib": gr.get("need_gib"),
             "cap_gib": gr.get("cap_gib"), "waited_s": gr.get("waited_s"), "enforcement": gr.get("enforcement")}
        if "proved" in last:
            p = last["proved"]
            r.update(verdict=p["verdict"], segments=p["segments"], receipt_bytes=p["receipt_bytes"], prove_s=p["prove_seconds"], total_s=p["total_seconds"], floor_bits=p["whole_run_floor_bits"])
        if "loaded" in last:
            r.update(identity=last["loaded"]["trained_statement_identity"], n=last["loaded"]["content_length_n"])
        if "classified" in last:
            c = last["classified"]
            r.update(verdict=c["verdict"], verify_s=c["verify_seconds"], floor_bits=c["whole_run_floor_bits"], root=c["input_token_endpoint_root"])
        if "content-checked" in last:
            r.update(owner="content-checked", content_total=last["content-checked"]["content_total"])
        if "label" in last:
            lb = last["label"]
            r.update(label=lb["label"], content_total=lb["content_total"], expect_total=lb["expect_total"], chunk_size=lb["chunk_size"], overlap=lb["overlap"])
        if "refused" in last:
            r.update(refused=last["refused"]["error"][:300])
        rows.append(r)
json.dump({"scope": "[MEASURED] round-16 real Shieldstral-1.0-3B T128 classifier runs on native R13, laptop, shared box, n=1", "binary_sha256": open(f"{L}/real-cli.log").read().split()[-2] if os.path.exists(f"{L}/real-cli.log") else None, "rows": rows}, open(OUT, "w"), indent=1)
for r in rows:
    extra = " ".join(f"{k}={r[k]}" for k in ("verdict", "label", "receipt_bytes", "segments", "prove_s", "total_s", "verify_s", "content_total", "floor_bits", "refused") if k in r)
    print(f"{r['category']:8s} {r['step']:6s} exit {r['exit']} wall {r['wall_s']:7.1f} s rss {r['peak_rss_gib']} cg {r['peak_cgroup_gib']} | {extra}")
