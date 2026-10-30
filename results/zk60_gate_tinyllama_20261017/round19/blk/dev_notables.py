#!/usr/bin/env python3
"""block-port dev: the no-public-table-values path on an R13 RUNG capture, its values stripped IN MEMORY"""
import json, os, sys, time, resource
S = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/staging_v22/scripts"
sys.path.insert(0, S)
import zk60_native_rg_classgate as CG, zk60_native_rg_r13blocks as RB
C = "/home/victor/zk60-artifacts/token-io/captures"
OUT = os.path.dirname(os.path.abspath(__file__))
out = {}
for name in sys.argv[1:]:
    t = time.time()
    b = CG.load(os.path.join(C, name))
    rp = CG.ClassRunReplay(b).run()
    stripped = 0
    for st in b.stages:
        if st.kind != "BLOCK":
            continue
        for arg in st.doc["arguments"]:
            for tab in arg["tables"]:
                if tab["kind"] == "public" and "values" in tab:
                    del tab["values"]
                    stripped += 1
    b.public_tables_included = False
    r = RB.r13_block_terminals(b, rp, controls=True)
    r["dev"] = {"values_stripped_in_memory": stripped, "seconds": round(time.time() - t, 1)}
    json.dump(r, open(os.path.join(OUT, f"dev-notables-{name}.json"), "w"), indent=1, default=str, sort_keys=True)
    out[name] = {"ok": r.get("ok"), "tables_absent_by_capture_option": r.get("tables_absent_by_capture_option"),
                 "per_stage": [(p["stage"], p["gate_shift"], p["slot_checks_equal"], p["slot_checks_expected"], p["open_by_capture_option"],
                                p["checked_not_equal"], [e["slot"] for e in p["refused_or_open"] if e["slot"] not in p["open_by_capture_option"]], p["seconds"])
                               for p in r["per_stage"]],
                 "controls": {k: (v.get("predicted"), v.get("failing"), v.get("fires")) for k, v in r["controls"].items() if isinstance(v, dict)},
                 "dev": r["dev"]}
    print(name, json.dumps(out[name]), flush=True)
print("peak_rss_mb", round(resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024))
