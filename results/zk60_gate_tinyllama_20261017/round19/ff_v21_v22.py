#!/usr/bin/env python3
"""[gate round 19] failing-first: frozen v21's pin rule and integrity on every round-19 capture (the R13 rung
captures and the real Shieldstral capture: expected refused), and frozen v22's on an r14 capture and an R-C1
capture (expected refused by name). Integrity only (no slot evaluation): light. Writes ff/ff-v21-pins-and-v22-on-old.json."""
import json, os, sys
E = "/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017"
GT = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama"
C = "/home/victor/zk60-artifacts/token-io/captures"
R19 = sorted(n for n in os.listdir(C) if n.startswith("classify-r13-"))
out = {"v21_on_r19": {}, "v22_on_old": {}}


def fresh(path):
    for k in [k for k in list(sys.modules) if k.startswith("zk60_")]:
        del sys.modules[k]
    sys.path[:] = [p for p in sys.path if not p.startswith(GT)]
    sys.path.insert(0, path)


fresh(GT + "/frozen_v21/scripts")
import zk60_native_rg_classgate as CG21  # noqa: E402
import zk60_native_rg_classpins as CP21  # noqa: E402
for n in R19:
    m = json.load(open(os.path.join(C, n, "manifest.json")))
    p = CP21.classify_capture_pins(m)
    rec = {"v21_pins_ok": p["ok"], "v21_pin_refusals": len(p["refusals"]), "first_refusals": p["refusals"][:3]}
    if n.startswith("classify-r13-rung"):
        b = CG21.load(os.path.join(C, n))
        i = CG21.class_integrity(b)
        rec.update({"v21_integrity_ok": i["ok"], "v21_other_findings": [x for x in i["findings"] if not x.startswith("source pin")][:4]})
    out["v21_on_r19"][n] = rec
fresh(GT + "/frozen_v22/scripts")
import zk60_native_rg_classgate as CG22  # noqa: E402
for n in ("classify-rc3-cli-p18-r14", "classify-rc3-rung-L2-v1-short20", "classify-rung-L1-v1"):
    b = CG22.load(os.path.join(C, n))
    i = CG22.class_integrity(b)
    out["v22_on_old"][n] = {"integrity_ok": i["ok"], "pin_refusals": i["source_pins"]["refusals"][:6]}
out["all_v21_refuse"] = all(not v["v21_pins_ok"] for v in out["v21_on_r19"].values())
out["v22_refuses_old"] = all(not v["integrity_ok"] for v in out["v22_on_old"].values())
os.makedirs(E + "/round19/ff", exist_ok=True)
json.dump(out, open(E + "/round19/ff/ff-v21-pins-and-v22-on-old.json", "w"), indent=1, default=str)
print(out["all_v21_refuse"], out["v22_refuses_old"], len(out["v21_on_r19"]))
sys.exit(0 if out["all_v21_refuse"] and out["v22_refuses_old"] else 1)
