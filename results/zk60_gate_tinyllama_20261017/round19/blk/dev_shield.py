#!/usr/bin/env python3
"""block-port dev: r13_block_terminals on the REAL Shieldstral capture, selected blocks only (timing / memory)"""
import json, os, sys, time, resource
S = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/staging_v22/scripts"
sys.path.insert(0, S)
import zk60_native_rg_classgate as CG, zk60_native_rg_r13blocks as RB
C = "/home/victor/zk60-artifacts/token-io/captures/classify-r13-shield-t128-cli-sexual-r16b"
OUT = os.path.dirname(os.path.abspath(__file__))
blocks = [int(x) for x in sys.argv[1].split(",")]
controls = len(sys.argv) > 2 and sys.argv[2] == "controls"
t = time.time()
b = CG.load(C)
tl = time.time() - t
rp = CG.ClassRunReplay(b).run()
tr = time.time() - t
rss_load = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024
r = RB.r13_block_terminals(b, rp, controls=controls, blocks=blocks,
                           calibration_export="/home/victor/IntelligenceRegulation/results/zk60_shieldstral_export_20261026/native_low_h24_t128")
r["dev"] = {"load_s": round(tl, 1), "load_plus_replay_s": round(tr, 1), "total_s": round(time.time() - t, 1),
            "peak_rss_mb_after_load_replay": round(rss_load), "peak_rss_mb": round(resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024),
            "replay_ok": rp.summary().get("ok")}
tag = "-".join(map(str, blocks)) + ("-ctl" if controls else "")
json.dump(r, open(os.path.join(OUT, f"dev-shield-{tag}.json"), "w"), indent=1, default=str, sort_keys=True)
print(json.dumps(r["dev"]), r.get("ok"), r.get("refused"))
for p in r.get("per_stage", []):
    print(p["stage"], p["gate_shift"], p["slot_checks_equal"], p["checked_not_equal"], [(e["slot"], e["why"][:200]) for e in p["refused_or_open"]], p["seconds"])
for k, v in (r.get("controls") or {}).items():
    print(k, v.get("predicted"), v.get("failing"), v.get("fires"))
print("export crosscheck", r.get("calibration_export_crosscheck"))
