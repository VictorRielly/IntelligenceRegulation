#!/usr/bin/env python3
"""[gate round 22] The round-21 counting script's GEOMETRY and draw formula (geometry() only; its refusal
check is Shieldstral's), applied to a rung capture, so that its per-part counts can be compared with the
seeded replay's by-value counts at the same geometry.  Lengths and counts only.  NOT a privacy result."""
import importlib.util, json, sys
spec = importlib.util.spec_from_file_location("crc", "/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017/round21/classify_run_counts.py")
C = importlib.util.module_from_spec(spec); spec.loader.exec_module(C)
g = C.geometry(sys.argv[1])
out = {"stages": [{"kind": s["kind"], "A": s["A"]["draws"], "H": s["H"]["draws"], "M": s["M"]["draws"], "salts": s["salts"]} for s in g["stages"]],
       "boundaries": [(b["name"], b["draws"], b["salts"]) for b in g["boundaries"]], "endpoint": g["endpoints"][0]}
out["draws"] = sum(x["A"] + x["H"] + x["M"] for x in out["stages"]) + sum(b[1] for b in out["boundaries"]) + out["endpoint"]["draws"]
out["salts"] = sum(x["salts"] for x in out["stages"]) + sum(b[2] for b in out["boundaries"]) + out["endpoint"]["salts"]
out["run_stream_draws"] = out["draws"] - out["endpoint"]["draws"]
out["run_stream_salts"] = out["salts"] - out["endpoint"]["salts"]
open(sys.argv[2], "w").write(json.dumps(out, indent=1) + "\n")
print(json.dumps({k: out[k] for k in ("draws", "salts", "run_stream_draws", "run_stream_salts")}), out["stages"], out["boundaries"])
