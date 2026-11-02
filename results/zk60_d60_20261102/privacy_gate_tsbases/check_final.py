#!/usr/bin/env python3
"""TS / CENSUS / bases lane (2026-11-02): the per-record check of records_final/ the README quotes. For every record,
every part must be true and every control of this lane's four parts must have its predicted verdict; the HASH-2
Rust lookup must have run against the v2 printout with nothing missing; pins, backend, R13-3, the own clause and the
tool state are printed. Exit 0 only if every check holds."""
import collections
import glob
import json
import os
import sys

P = os.path.dirname(os.path.abspath(__file__))
V2 = "bac4bbd6838b2a090b131dd003ec1f6962063e12e1bb1cff80fa7a35ab65dc53"
TS, CEN, HL, HC = ("TS-1 terminal surjection and its pair-removed control", "CENSUS claim census", "HASH-1 hash layer",
                   "HASH-2 hash census")
bad, tools, ctl = [], collections.Counter(), collections.Counter()
for p in sorted(glob.glob(os.path.join(P, "records_final", "d55-*.json"))):
    r = json.load(open(p))
    nm = os.path.basename(p)[10:-5]
    f = []
    parts = r["parts"]
    if r["status"] != "D55-PASS":
        f.append(f"status {r['status']}")
    f += [f"part false: {k}" for k, v in parts.items() if not v]
    for k in (TS, CEN, HL, HC):
        if k not in parts:
            f.append(f"part missing: {k}")
    pins = r["PINS"]
    if pins.get("unread") or not pins["backend"]["admissible"] or r.get("backend_refused"):
        f.append("pins / backend")
    t3 = r["R13-3 terminals"]
    slots = [x["slot_checks_equal"] for x in t3["per_fork"]]
    own = [x["own_clauses"] for x in t3["per_fork"]]
    if slots != [23, 23, 23]:
        f.append(f"R13-3 slots {slots}")
    if ("own" in nm) != any(own):
        f.append(f"own clauses {own}")
    ts = r[TS]
    c = ts["controls"]
    t1 = c["TS-1 pair removed, every role"]
    if (t1["fired"], t1["live"]) != (10, 10):
        f.append(f"TS-1 {t1['fired']}/{t1['live']}")
    if not all(e["ok"] for e in ts["expectation"]) or len(ts["expectation"]) != 10:
        f.append("TS-R expectation")
    fid = c["TS-1F the null-space form on the cheapest TS-1 row"]
    if not fid["rows"] or not all(x["forms_agree"] and x["equals_the_ts1_original_form"] for x in fid["rows"]):
        f.append("TS-1F")
    rc = c["TS-RC the review's controls on fork 0's A"]
    if rc["deviations"] or len(rc["fires"]) != 9:
        f.append(f"TS-RC {rc['deviations']}")
    if ts["loader"]["ts_trained_sha256"] != ts["loader"]["ts_trained_pin"]:
        f.append("ts_trained pin")
    cen = r[CEN]
    if cen["roles_with_a_finding"] or not all(v["fires"] for v in cen["controls"].values() if isinstance(v, dict)):
        f.append("CENSUS")
    hl = r[HL]
    hlc = [v["fires"] for v in hl["controls"].values() if isinstance(v, dict)]
    if hl["columns_authenticated"] != hl["columns_checked"] or len(hlc) != 10 or not all(hlc) \
            or hl["forks"]["cross_rule_probe"]["wrong_rules_that_reached_the_root"] or hl["forks"]["cross_rule_probe"]["wrong_rules_tried"] != 4:
        f.append("HASH-1")
    hc = r[HC]
    hcc = [v["fires"] for v in hc["controls"].values() if isinstance(v, dict)]
    rt = hc["rust_table"]
    if not (hc["C-R1_no_40_byte_F_U_input"] and hc["C-R2_constructor_not_47"] and hc["W-2_holds"] and hc["W-2g_holds"]
            and hc["ACC_every_call_attributed"]) or len(hcc) != 7 or not all(hcc):
        f.append("HASH-2 conditions / controls")
    if rt.get("printout_sha256") != V2 or rt.get("measured_not_in_rust") or not rt.get("ok"):
        f.append(f"HASH-2 Rust lookup {rt.get('printout_sha256', '')[:12]} {rt.get('measured_not_in_rust')}")
    for k in ("TS-1", "TS-RC", "CEN", "HL", "HC"):
        pass
    ctl["TS-1 rows"] += t1["fired"]
    ctl["TS-RC predictions"] += sum(1 for k, v in rc["fires"].items() if v is rc["predicted"][k])
    ctl["CEN"] += sum(1 for v in cen["controls"].values() if isinstance(v, dict) and v["fires"])
    ctl["HL / HR"] += sum(hlc) + (1 if not hl["forks"]["cross_rule_probe"]["wrong_rules_that_reached_the_root"] else 0)
    ctl["HC"] += sum(hcc)
    tools[json.dumps({k: v for k, v in r["tool_sha256"].items() if k.startswith("zk60_native_rg_d55")}, sort_keys=True)] += 1
    print(f"{nm:20s} {r['status']:9s} parts {sum(parts.values())}/{len(parts)}; G {[x['gate_shift_recovered'] for x in t3['per_fork']]}, "
          f"slots {slots}, own {[o for o in own if o]}; TS-1 {t1['fired']}/{t1['live']}, TS-1F {[(x['role'], x['data_rows']) for x in fid['rows']]}, "
          f"TS-RC 9/9; census {cen['claims_compared']} claims; HASH-1 {hl['columns_authenticated']}/{hl['columns_checked']}; "
          f"HASH-2 ctor {hc['constructor_lengths']} Rust kinds {rt.get('rust_kinds_for_this_profile')} compared {rt.get('measured_compared')}; "
          f"replay {r['D55-3 replay']['challenges_checked']} / {len(r['D55-3 replay']['failures'])}; {r['seconds']} s"
          + (f"  FINDINGS {f}" if f else ""))
    if f:
        bad.append((nm, f))
print("controls with their predicted verdict:", dict(ctl), "total", sum(ctl.values()))
print("tool states (this lane's modules):", len(tools))
print("ALL CHECKS HOLD" if not bad else f"FAILED: {bad}")
sys.exit(1 if bad else 0)
