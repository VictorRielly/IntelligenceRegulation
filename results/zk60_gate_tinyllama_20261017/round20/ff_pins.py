#!/usr/bin/env python3
"""[gate round 20] failing-first on the PIN RULE (manifest-only, light): frozen v22's
`classify_capture_pins` on the two token frozen-r17 captures (refused by name, expected),
staging/frozen v23's on the same (accepted) and on round 19's r16b captures (accepted) and an
r14 / R-C1 capture (refused by name); v23's r17 self-check against the token manifests.

    python3 ff_pins.py <v22-scripts> <v23-scripts> <out.json>
"""
import importlib
import json
import os
import sys

C = "/home/victor/zk60-artifacts/token-io/captures"
R17 = ["classify-r13-shield-t128-cli-hate-r17-values", "classify-r13-rung-L2-v1-r17-values"]
R16B = ["classify-r13-shield-t128-cli-sexual-r16b", "classify-r13-rung-L2-v1-short11"]
OLD = ["classify-rc3-rung-L2-v1-short20", "classify-rung-L2-v1"]


def rule(scripts):
    """import one tool version's pin rule; its lazy imports need its directory on
    sys.path while it runs, so the previous version's modules and path are dropped"""
    for m in [k for k in list(sys.modules) if k.startswith("zk60_")]:
        del sys.modules[m]
    for q in [q for q in sys.path if q.endswith("/scripts") and "gate-tinyllama" in q]:
        sys.path.remove(q)
    sys.path.insert(0, scripts)
    return importlib.import_module("zk60_native_rg_classpins")


def man(name):
    return json.load(open(os.path.join(C, name, "manifest.json")))


def run(cp, names):
    out = {}
    for n in names:
        if not os.path.isdir(os.path.join(C, n)):
            out[n] = {"absent": True}
            continue
        r = cp.classify_capture_pins(man(n))
        out[n] = {"ok": r["ok"], "pins": r["pins"], "refusals": r["refusals"], "port": r.get("port"),
                  "statuses": sorted({x["status"].split(":")[0] for x in r["per_file"]})}
    return out


def main(v22, v23, path):
    rec = {"what": "gate round 20 failing-first on the pin rule (manifest only); not a privacy result"}
    cp22 = rule(v22)
    rec["v22"] = {"scripts": v22, "r17": run(cp22, R17), "r16b": run(cp22, R16B)}
    cp23 = rule(v23)
    rec["v23"] = {"scripts": v23, "r17": run(cp23, R17), "r16b": run(cp23, R16B), "old": run(cp23, OLD),
                  "r17_self_check": cp23.r17_self_check()}
    ok = (all(not v["ok"] for v in rec["v22"]["r17"].values())
          and all(any("run_capture.rs: cce0fc2a4062 has no reading" in x for x in v["refusals"]) and len(v["refusals"]) == 1
                  for v in rec["v22"]["r17"].values())
          and all(v["ok"] for v in rec["v22"]["r16b"].values())
          and all(v["ok"] and v["pins"] == 72 for v in rec["v23"]["r17"].values())
          and all(v["ok"] for v in rec["v23"]["r16b"].values())
          and all(not v["ok"] for v in rec["v23"]["old"].values() if not v.get("absent"))
          and rec["v23"]["r17_self_check"]["ok"])
    rec["ok"] = ok
    json.dump(rec, open(path, "w"), indent=1, sort_keys=True, default=str)
    print("ok", ok)
    for k in ("v22", "v23"):
        for grp in ("r17", "r16b", "old"):
            for n, v in rec[k].get(grp, {}).items():
                print(k, grp, n, v.get("ok"), v.get("pins"), (v.get("refusals") or [])[:2])
    print("self-check", rec["v23"]["r17_self_check"])
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main(*sys.argv[1:4]))
