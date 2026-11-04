"""v25 freeze fixes, regression evidence (read-only): what the FIXED status
rules say about D55 records the pre-fix tool state wrote.  For each record:
the parts as recorded; `controls_run` / `joint_run` from the parts present
(pre-fix records do not carry the flags); PINS as recorded AND the writer's
exact pin set (`pin_set_check` on the bundle's manifest, read from the
record's bundle_dir); HASH-2 counted false unless the record's printout digest
is the pinned one (FR25-01 / -02); `not_here` without the self-read line only
when the record's self-read pins are exactly the three FR25-13 relabels; then
`d55_status`.  No figure is recomputed.

    python3 -B exp_restatus.py <staging_v25/scripts> <record.json> [...]"""
import json
import os
import sys

sys.path.insert(0, sys.argv[1])
import zk60_native_rg_d55 as D  # noqa: E402
import zk60_native_rg_d55hash as H  # noqa: E402
import zk60_native_rg_r26readings as R26  # noqa: E402

SELF_READ_LINE = "the independent check of the self-read readings (READINGS_R26_WIRING.json) at the v25 freeze review"
RELABELLED = sorted(f for (f, _p), v in R26.R26_READINGS.items() if v[2] == R26.WIRING_CHECKED)

for path in sys.argv[2:]:
    rec = json.load(open(path))
    parts = dict(rec.get("parts", {}))
    pins = rec.get("PINS", {})
    man_path = os.path.join(rec.get("bundle_dir", ""), "manifest.json")
    man = json.load(open(man_path)) if os.path.isfile(man_path) else None
    ps = D.pin_set_check(man) if man is not None else {"ok": False, "refused": "manifest not found"}
    w16_prefix_reads = sorted(pins.get("readings") or {})
    pins_ok = bool(pins.get("ok")) and ps["ok"] and not w16_prefix_reads
    rt = (rec.get("HASH-2 hash census") or {}).get("rust_table") or {}
    printout_pinned = rt.get("printout_sha256") == H.S25_W2_PRINTOUT_PIN
    if "HASH-2 hash census" in parts and not printout_pinned:
        parts["HASH-2 hash census"] = False
    not_here = list(rec.get("not_here", []))
    if sorted(pins.get("self_read_pending_independent_check") or []) == RELABELLED:
        not_here = [x for x in not_here if x != SELF_READ_LINE]
    controls_run = "D55-C replay controls" in parts and "PINS controls" in parts
    joint_run = "D55-J joint rank" in parts
    s = D.d55_status(parts, pins_ok, rec.get("family", "W16"), not_here, controls_run, joint_run)
    print(f"{os.path.basename(path)}: {rec.get('status')} -> {s['status']}  parts {sum(map(bool, parts.values()))}/{len(parts)}, "
          f"controls {controls_run}, joint {joint_run}, printout pinned {printout_pinned}, pin set {ps['ok']} "
          f"({ps.get('declared')}/{ps.get('expected')}), W16 prefix reads {w16_prefix_reads}")
    for r in s["status_reasons"]:
        print(f"    below PASS: {r}")
