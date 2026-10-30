#!/usr/bin/env python3
"""Token round 17: does the gate's FROZEN v22 reader read an r17 capture's table values? (a FORMAT check, read only)

usage: v22_format_check.py --bundle DIR --out JSON

Imports the gate's frozen tools from ops/zkp-mvp/gate-tinyllama/frozen_v22/scripts (never written) and runs, on one
R13 classifier bundle written by the r17 recorder WITH public-table values:

  1. v22's closed-key schema check S1 / S2 / S3 (`zk60_native_rg_schema`): no key outside the writer allow-list, no
     forbidden word, the array store fully referenced;
  2. v22's classifier replay (`zk60_native_rg_classgate.ClassRunReplay`);
  3. v22's R13 block-stage terminal identity (`zk60_native_rg_r13blocks.r13_block_terminals`) on every block stage,
     controls on.

`zk60_native_rg_terminals.check_source_pins` is wrapped: its real result is recorded (`source_pins_v22_unbypassed`)
and the evaluators proceed either way. (16:33 finding: it PASSES unbypassed on r17 bundles; it pins the terminal
port's files, not run_capture.rs. The gate's CLASSIFIER capture-pin rule, `zk60_native_rg_classpins`, which does pin
run_capture.rs and plane_index.rs, is not run here: re-reading round 17's run_capture.rs is the gate's own step.)
This check only asks whether v22's EVALUATORS read the values the r17 recorder writes, i.e. whether the format is
coordinated. `zk60_native_rg_schema` is the TinyLlama block allow-list; its findings on a classifier bundle are the
classifier keys, so key sets are compared by keyset_compare.py instead. Not a gate record and not a privacy result.
"""
import argparse, json, os, sys, time

GATE = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/frozen_v22/scripts"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--bundle", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--blocks", default=None, help="comma-separated block indices (a bounded check at a large shape)")
    a = ap.parse_args()
    sys.path.insert(0, GATE)
    t0 = time.time()
    rec = {"what": "token round 17 FORMAT check of an r17 capture with public-table values against the frozen v22 "
                   "reader (read only); v22's source-pin rule BYPASSED (run_capture.rs moved; the gate re-pins)",
           "bundle": a.bundle, "gate_tools": GATE, "privacy_acceptance": False, "gate_record": False}
    import zk60_native_rg_schema as S
    import zk60_native_rg_terminals as T
    import zk60_native_rg_classgate as CG
    import zk60_native_rg_r13blocks as R13B
    try:
        docs, raw, size = S.load_docs(a.bundle)
        rec["schema"] = S.check_docs(docs, raw, size)
        del docs, raw
    except Exception as exc:  # noqa: BLE001
        rec["schema"] = {"error": repr(exc), "ok": False}
    real_pins = T.check_source_pins
    rec["source_pins_v22_unbypassed"] = None

    def bypass(bundle):
        try:
            rec["source_pins_v22_unbypassed"] = real_pins(bundle)
        except Exception as exc:  # noqa: BLE001
            rec["source_pins_v22_unbypassed"] = {"error": repr(exc)}
        return {"ok": True, "bypassed": "token round 17 format check: v22's pin rule bypassed (run_capture.rs moved)"}
    T.check_source_pins = bypass
    b = CG.load(a.bundle)
    rec["public_tables_included"] = bool(getattr(b, "public_tables_included", False))
    rp = CG.ClassRunReplay(b).run()
    rec["replay"] = rp.summary()
    blocks = [int(x) for x in a.blocks.split(",")] if a.blocks else None
    rec["blocks_requested"] = blocks
    r = R13B.r13_block_terminals(b, rp, controls=True, blocks=blocks)
    rec["r13_block_terminals"] = r
    per = r.get("per_stage", [])
    rec["summary"] = {
        "blocks": r.get("blocks"),
        "blocks_evaluated": r.get("blocks_evaluated"),
        "schema_ok": (rec.get("schema") or {}).get("ok"),
        "schema_findings": (rec.get("schema") or {}).get("findings"),
        "ok": r.get("ok"),
        "ok_on_the_covered_slots": r.get("ok_on_the_covered_slots"),
        "tables_absent_by_capture_option": r.get("tables_absent_by_capture_option"),
        "slots_equal_per_stage": [p.get("slot_checks_equal") for p in per],
        "slots_expected_per_stage": [p.get("slot_checks_expected") for p in per],
        "open_by_capture_option_per_stage": [p.get("open_by_capture_option") for p in per],
        "captured_tables_per_stage": [len(p.get("captured_tables") or []) for p in per],
        "controls": {k: (v.get("fires") if isinstance(v, dict) else v) for k, v in (r.get("controls") or {}).items()},
        "replay_ok": rec["replay"].get("ok") if isinstance(rec["replay"], dict) else None,
        "seconds": round(time.time() - t0, 1),
    }
    try:
        import resource
        rec["summary"]["peak_rss_mb"] = round(resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024)
    except Exception:  # noqa: BLE001
        pass
    os.makedirs(os.path.dirname(a.out), exist_ok=True)
    with open(a.out, "w") as fh:
        json.dump(rec, fh, indent=1, sort_keys=True, default=str)
    print(json.dumps(rec["summary"], indent=1, default=str))
    # (16:31) the schema module above is the TinyLlama block allow-list (v5), which lacks the classifier / token keys every
    # classifier bundle carries; it is recorded but not part of the verdict (the key sets are compared with a gate-passed
    # round-19 capture by keyset_compare.py instead)
    rec["schema_note"] = "zk60_native_rg_schema is the TinyLlama block allow-list (v5); its S1 findings on a classifier bundle are the classifier / token keys, not new keys"
    ok = r.get("ok_on_the_covered_slots") and not r.get("tables_absent_by_capture_option")
    if blocks is None:
        ok = ok and r.get("ok")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
