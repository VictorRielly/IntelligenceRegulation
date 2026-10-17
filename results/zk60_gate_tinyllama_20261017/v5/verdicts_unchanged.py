#!/usr/bin/env python3
"""NO EXISTING RECORD CHANGES VERDICT UNDER TOOLS v5 (review finding P-2):
for every staged record of this lane, recompute

  * the source-pin verdict with v5's `check_run_layer_pins` (which now folds
    the shared files and finding G-2 in) on the bundle's own manifest,
  * the v5 driver's `ok` rule (every stage's ok EXACTLY true, and the pins),
  * the v5 status (PASS needs every false leaf explained by (e) only; ARMS-ONLY
    needs stages 1-3 and the arms; non-bool leaves flagged),

and compare them with what the record says (its `ok`) and with the v4 status
(the frozen v4 classifier).  Only the manifest of each bundle is read, so no
bundle is loaded.

    python3 verdicts_unchanged.py <out.json>
"""
import glob
import importlib.util
import json
import os
import sys
import types

GATE = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama"
EV = "/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017"
sys.path.insert(0, os.path.join(GATE, "scripts"))
import zk60_native_rg_runpins as RP  # noqa: E402
import zk60_native_rg_status as S5  # noqa: E402

spec = importlib.util.spec_from_file_location(
    "v4_status", os.path.join(GATE, "frozen_v4", "scripts", "zk60_native_rg_status.py"))
S4 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(S4)


def records():
    pats = ["l1/*.json", "l2/*.json", "l22/*.json", "p2/*.json", "v4/*.json",
            "equivalence/*-ported.json", "equivalence/*-original.json"]
    out = []
    for p in pats:
        for f in sorted(glob.glob(os.path.join(EV, p))):
            if f.endswith(".status.json") or f.endswith(".guard.json"):
                continue
            try:
                r = json.load(open(f))
            except Exception:  # noqa: BLE001
                continue
            if isinstance(r, dict) and "stages_run" in r and "bundle_dir" in r:
                out.append((f, r))
    return out


def main():
    rows = []
    for f, r in records():
        man = json.load(open(os.path.join(r["bundle_dir"], "manifest.json")))
        pins = RP.check_run_layer_pins(types.SimpleNamespace(manifest=man))
        done = [k for k in r if k.startswith("stage") and k != "stages_run"]
        v5_ok = bool(all(isinstance(r[k], dict) and r[k].get("ok") is True for k in done)
                     and pins["ok"] is True)
        s5 = S5.classify(r)
        s4 = S4.classify(r)
        rows.append({
            "record": os.path.relpath(f, EV),
            "recorded_ok": r.get("ok"),
            "v5_pins_ok": pins["ok"],
            "v5_pins_would_suspend": sorted(pins["stages_not_checked"]),
            "v5_driver_ok": v5_ok,
            "ok_unchanged": v5_ok == r.get("ok"),
            "v4_status": s4["status"],
            "v5_status": s5["status"],
            "status_unchanged": s4["status"] == s5["status"],
            "v4_unexplained": len(s4["unexplained"]),
            "v5_unexplained": len(s5["unexplained"]),
            "v5_non_bool_leaves": s5["non_bool_leaves"],
        })
    out = {
        "what": __doc__.strip().splitlines()[0],
        "records": len(rows),
        "every_pin_check_ok": all(x["v5_pins_ok"] for x in rows),
        "every_ok_unchanged": all(x["ok_unchanged"] for x in rows),
        "every_status_unchanged": all(x["status_unchanged"] for x in rows),
        "status_changes": [x for x in rows if not x["status_unchanged"]],
        "ok_changes": [x for x in rows if not x["ok_unchanged"]],
        "rows": rows,
    }
    out["ok"] = out["every_pin_check_ok"] and out["every_ok_unchanged"] and out["every_status_unchanged"]
    json.dump(out, open(sys.argv[1], "w"), indent=1, sort_keys=True)
    for x in rows:
        print(f"{x['record']:52s} ok {x['recorded_ok']!s:5s}->{x['v5_driver_ok']!s:5s} "
              f"pins {x['v5_pins_ok']!s:5s} status {x['v4_status']}->{x['v5_status']} "
              f"unexpl {x['v4_unexplained']}->{x['v5_unexplained']}")
    print(f"records {len(rows)}; ok unchanged {out['every_ok_unchanged']}; status "
          f"unchanged {out['every_status_unchanged']}; pins ok {out['every_pin_check_ok']}")
    return 0 if out["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
