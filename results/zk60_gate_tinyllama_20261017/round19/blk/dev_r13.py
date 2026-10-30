#!/usr/bin/env python3
"""block-port dev runner: r13_block_terminals on R13 captures (and the legacy one), records to blk/"""
import json, os, sys, time, resource
S = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/staging_v22/scripts"
sys.path.insert(0, S)
import zk60_native_rg_classgate as CG, zk60_native_rg_r13blocks as RB
C = "/home/victor/zk60-artifacts/token-io/captures"
OUT = os.path.dirname(os.path.abspath(__file__))
summary = {}
for name in sys.argv[1:]:
    t = time.time()
    b = CG.load(os.path.join(C, name))
    rp = CG.ClassRunReplay(b).run()
    r = RB.r13_block_terminals(b, rp, controls=True)
    r["replay_ok"] = rp.summary().get("ok")
    r["dev_seconds"] = round(time.time() - t, 1)
    json.dump(r, open(os.path.join(OUT, f"dev-{name}.json"), "w"), indent=1, default=str, sort_keys=True)
    summary[name] = {"ok": r.get("ok"), "r13": r.get("r13"), "replay_ok": r["replay_ok"], "seconds": r["dev_seconds"],
                     "per_stage": [(p["stage"], p.get("gate_shift"), p["slot_checks_equal"], p["slot_checks_expected"],
                                    p["checked_not_equal"], [e["slot"] for e in p["refused_or_open"]]) for p in r.get("per_stage", [])],
                     "controls": {k: v.get("fires") for k, v in (r.get("controls") or {}).items() if isinstance(v, dict)},
                     "refused": r.get("refused")}
    print(name, json.dumps(summary[name]), flush=True)
summary["peak_rss_mb"] = round(resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024)
json.dump(summary, open(os.path.join(OUT, "dev_summary.json"), "w"), indent=1, default=str)
print("peak_rss_mb", summary["peak_rss_mb"])
