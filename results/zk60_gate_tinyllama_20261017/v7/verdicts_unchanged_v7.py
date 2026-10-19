#!/usr/bin/env python3
"""NO EXISTING RECORD CHANGES VERDICT UNDER TOOLS v7 (round 6): for every
staged record of this lane (tree A, R5 port, R5b), recompute

  * the source-pin verdict with v7's `check_run_layer_pins` on the bundle's
    own manifest,
  * the v7 driver's `ok` rule (every stage's ok EXACTLY true, and the pins),
  * the v7 status classifier,

and compare with the record's own `ok` and with the FROZEN v6 classifier.
v7 changes M9-3's criterion (G-4 / review Q-8), PC-9 (PC-9b) and the G-10
legacy loader's sys.path hygiene: none of these is read when a record is
re-classified, so every verdict must come out unchanged.  The records whose
verdict v7 is MEANT to change (NOT-OK solely by M9-3) change only when the
pass is RE-RUN; that is shown separately by `leafdiff_v7.py`.

    python3 verdicts_unchanged_v7.py <out.json>
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
import zk60_native_rg_status as S7  # noqa: E402

spec = importlib.util.spec_from_file_location(
    "v6_status", os.path.join(GATE, "frozen_v6", "scripts", "zk60_native_rg_status.py"))
S6 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(S6)


def records():
    pats = ["l1/*.json", "l2/*.json", "l22/*.json", "p2/*.json", "v4/*.json",
            "v5/*.json", "gr4/*.json", "gr4/*/*.json",
            "r5b/l1/*.json", "r5b/l2/*.json", "r5b/l22/*.json",
            "r5b/l1/*/*.json", "r5b/probe_before_repin/*.json",
            "equivalence/*-ported.json", "equivalence/*-original.json"]
    out, seen = [], set()
    for p in pats:
        for f in sorted(glob.glob(os.path.join(EV, p))):
            if f in seen or f.endswith(".status.json") or f.endswith(".guard.json"):
                continue
            seen.add(f)
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
        mpath = os.path.join(r["bundle_dir"], "manifest.json")
        if not os.path.exists(mpath):
            rows.append({"record": os.path.relpath(f, EV), "skipped": "bundle manifest absent"})
            continue
        man = json.load(open(mpath))
        disk = RP.check_run_layer_pins(types.SimpleNamespace(manifest=man))
        recorded_pins = (r.get("run_layer_source_pins") or {}).get("ok")
        # a pin control's record was made from a MUTATED manifest (in memory):
        # its pin verdict is the record's own, never the on-disk manifest's
        mutated = "pincontrols" in f
        pins = {"ok": recorded_pins} if mutated else disk
        done = [k for k in r if k.startswith("stage") and k != "stages_run"]
        v7_ok = bool(all(isinstance(r[k], dict) and r[k].get("ok") is True for k in done)
                     and pins["ok"] is True)
        s7, s6 = S7.classify(r), S6.classify(r)
        rows.append({
            "record": os.path.relpath(f, EV),
            "recorded_ok": r.get("ok"),
            "v7_pins_ok": pins["ok"],
            "pins_from": "the record (a pin control's mutated manifest)" if mutated
            else "v7 check_run_layer_pins on the bundle's on-disk manifest",
            "v7_pins_on_disk_ok": disk["ok"],
            "recorded_pins_ok": recorded_pins,
            "v7_driver_ok": v7_ok,
            "ok_unchanged": v7_ok == r.get("ok"),
            "v6_status": s6["status"],
            "v7_status": s7["status"],
            "status_unchanged": s6["status"] == s7["status"],
            "v6_unexplained": len(s6["unexplained"]),
            "v7_unexplained": len(s7["unexplained"]),
        })
    live = [x for x in rows if "skipped" not in x]
    out = {
        "what": __doc__.strip().splitlines()[0],
        "privacy_acceptance": False,
        "records": len(live),
        "records_skipped": [x for x in rows if "skipped" in x],
        "every_ok_unchanged": all(x["ok_unchanged"] for x in live),
        "every_status_unchanged": all(x["status_unchanged"] for x in live),
        "status_changes": [x for x in live if not x["status_unchanged"]],
        "ok_changes": [x for x in live if not x["ok_unchanged"]],
        "rows": rows,
    }
    out["ok"] = out["every_ok_unchanged"] and out["every_status_unchanged"]
    json.dump(out, open(sys.argv[1], "w"), indent=1, sort_keys=True)
    for x in live:
        print(f"{x['record']:60s} ok {x['recorded_ok']!s:5s}->{x['v7_driver_ok']!s:5s} "
              f"pins {x['v7_pins_ok']!s:5s} status {x['v6_status']}->{x['v7_status']}")
    print(f"records {len(live)} (skipped {len(rows) - len(live)}); ok unchanged "
          f"{out['every_ok_unchanged']}; status unchanged {out['every_status_unchanged']}")
    return 0 if out["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
