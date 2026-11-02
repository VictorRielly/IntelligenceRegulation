#!/usr/bin/env python3
"""TS / CENSUS / bases lane (2026-11-02): print the figures of every D55 record in records/ (the README's tables) and
the control totals.  Usage: summarize.py [records dir]"""
import glob
import json
import os
import sys

D = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "records")
TS, CEN, HL, HC = ("TS-1 terminal surjection and its pair-removed control", "CENSUS claim census", "HASH-1 hash layer",
                   "HASH-2 hash census")
fired = total = 0


def count(ctl):
    global fired, total
    for k, v in (ctl or {}).items():
        if isinstance(v, dict) and "fires" in v:
            total += 1
            fired += bool(v["fires"])


for p in sorted(glob.glob(os.path.join(D, "d55-*.json"))):
    r = json.load(open(p))
    nm = os.path.basename(p)[4:-5]
    parts = r.get("parts", {})
    pins = r.get("PINS", {})
    print(f"=== {nm}: {r.get('status')}  ({r.get('seconds')} s, peak {r.get('peak_rss_mb')} MB)  profile {r.get('profile')}")
    print(f"  parts: {sum(parts.values())}/{len(parts)} true; false: {[k for k, v in parts.items() if not v]}")
    print(f"  pins: {pins.get('pins')} declared, {pins.get('at_r19b')} at r19b, {len(pins.get('read_here', []))} read, "
          f"{len(pins.get('unread', []))} unread; backend admissible {pins.get('backend', {}).get('admissible')}; "
          f"self-read {pins.get('self_read_pending_independent_check')}")
    t3 = r.get("R13-3 terminals", {})
    if t3:
        print(f"  R13-3: G per fork {[f.get('gate_shift_recovered') for f in t3.get('per_fork', [])]}, slots "
              f"{[f.get('slot_checks_equal') for f in t3.get('per_fork', [])]}, own clauses "
              f"{[f.get('own_clauses') for f in t3.get('per_fork', [])]}")
    rp = r.get("D55-3 replay", {})
    print(f"  replay: {rp.get('challenges_checked')} challenges, {len(rp.get('failures', []))} failures")
    ts = r.get(TS, {})
    if ts:
        print(f"  TS-1: ok {ts.get('ok')}; {len(ts.get('roles_read', []))} roles, {ts.get('arrays_checked')} arrays checked, "
              f"{ts.get('workers')} workers, {ts.get('seconds')} s (tasks {ts.get('task_seconds_wall')} s)")
        for k, v in (ts.get("summary") or {}).items():
            print(f"     {k:14s} rows {v['rows']:5d} groups {v['groups']:3d} onto {v['surjective']:3d} disclosed {v['disclosed_Fp']} joint {v['joint']}")
        bad = [e for e in ts.get("expectation", []) if not e["ok"]]
        print(f"     expectation: {len(ts.get('expectation', [])) - len(bad)}/{len(ts.get('expectation', []))} ok {bad[:2]}")
        c = ts.get("controls", {})
        t1 = c.get("TS-1 pair removed, every role", {})
        print(f"     TS-1 rows: {t1.get('fired')}/{t1.get('live')} fire; not applicable {t1.get('not_applicable')}; "
              f"pair-removed disclosed {[(x.get('role'), x.get('data_rows'), x.get('pair_removed_disclosed_Fp')) for x in t1.get('rows', [])]}")
        for x in t1.get("rows", []):
            if "fires" in x:
                total += 1
                fired += bool(x["fires"])
        f1 = c.get("TS-1F the null-space form on the cheapest TS-1 row", {})
        print(f"     TS-1F: ok {f1.get('ok')} {[(x['role'], x['data_rows'], x['null_space_form_disclosed_Fp'], x['original_form_disclosed_Fp'], x['forms_agree']) for x in f1.get('rows', [])]} {f1.get('not_run', '')}")
        rc = c.get("TS-RC the review's controls on fork 0's A", {})
        print(f"     TS-RC: ok {rc.get('ok')} on {rc.get('role')} group {rc.get('group')}; deviations {rc.get('deviations')}")
        for kk, vv in (rc.get("fires") or {}).items():
            total += 1
            fired += vv is rc["predicted"][kk]
    cen = r.get(CEN, {})
    if cen:
        print(f"  CENSUS: ok {cen.get('ok')}; {cen.get('claims_compared')} claims over {len(cen.get('roles', []))} roles; "
              f"roles with a finding {cen.get('roles_with_a_finding')}; controls {[(k[:5], v['fires']) for k, v in (cen.get('controls') or {}).items() if isinstance(v, dict)]}")
        count(cen.get("controls"))
    hl = r.get(HL, {})
    if hl:
        print(f"  HASH-1: ok {hl.get('ok')}; {hl.get('openings')} openings, {hl.get('columns_authenticated')}/{hl.get('columns_checked')} "
              f"columns; salted leaves forks {hl.get('distinct_salted_leaves_forks')} tail {hl.get('distinct_salted_leaves_tail')}; "
              f"cross-rule probe wrong rules reaching the root {hl.get('forks', {}).get('cross_rule_probe', {}).get('wrong_rules_that_reached_the_root')}")
        print(f"     controls {[(k[:5], v['fires']) for k, v in (hl.get('controls') or {}).items() if isinstance(v, dict)]}")
        count(hl.get("controls"))
    hc = r.get(HC, {})
    if hc:
        rt = hc.get("rust_table", {})
        print(f"  HASH-2: ok {hc.get('ok')}; {hc.get('calls')} BLAKE3 calls ({hc.get('transcript_calls')} transcript), "
              f"constructor {hc.get('constructor_lengths')}, C-R1 {hc.get('C-R1_no_40_byte_F_U_input')}, C-R2 {hc.get('C-R2_constructor_not_47')}, "
              f"W-2 {hc.get('W-2_holds')}, W-2g {hc.get('W-2g_holds')} ({len(hc.get('W-2g_declared_pairs', []))} declared pairs), "
              f"ACC {hc.get('ACC_every_call_attributed')}; within one byte {len(hc.get('pairs_within_one_byte', []))}")
        print(f"     Rust table: {rt.get('rust_kinds_for_this_profile', rt.get('not_compared'))} kinds, {rt.get('measured_compared')} compared, "
              f"not in Rust {rt.get('measured_not_in_rust')}; findings {hc.get('findings')}")
        print(f"     controls {[(k[:5], v['fires']) for k, v in (hc.get('controls') or {}).items() if isinstance(v, dict)]}")
        count(hc.get("controls"))
    print(f"  not_here: {r.get('not_here')}")
print(f"\nTHIS LANE'S CONTROLS: {fired} of {total} verdicts as predicted (TS-1 rows, TS-RC predictions, CEN, HL/HR, HC)")
