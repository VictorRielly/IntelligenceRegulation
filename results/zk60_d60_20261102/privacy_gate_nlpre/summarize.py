#!/usr/bin/env python3
"""NL-1 / PRE lane (2026-11-02): the figures of the D55 records in records/ (the parts, NL-1, PRE and every control
verdict), printed for the README.  Usage: summarize.py [records dir]"""
import glob
import json
import os
import sys

D = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "records")
NL, PRE = "NL-1 R13 slots, every fork", "PRE full zero-data preimage"
total_ctl, fired_ctl, na_ctl = 0, 0, []


def verdicts(rec):
    """every control verdict of the record: (name, fires) -- the parts' own, and this lane's"""
    out = []

    def walk(prefix, x):
        if isinstance(x, dict):
            if "fires" in x and isinstance(x.get("fires"), (bool, type(None))):
                out.append((prefix, x["fires"]))
            for k, v in x.items():
                if k in ("S1", "S4", "T0_E0", "per_commitment", "ir_run_challenges", "S3_rows", "rows"):
                    continue
                walk(f"{prefix}/{k}", v)
        elif isinstance(x, list):
            for i, v in enumerate(x):
                walk(f"{prefix}[{i}]", v)
    for part in rec.get("parts", {}):
        walk(part, rec.get(part))
    return out


for path in sorted(glob.glob(os.path.join(D, "d55-*.json"))):
    rec = json.load(open(path))
    name = os.path.basename(path)[4:-5]
    parts = rec.get("parts", {})
    print(f"== {name}: status {rec.get('status')}  ({rec.get('seconds')} s, peak {rec.get('peak_rss_mb')} MB)")
    print("   parts: " + ", ".join(f"{k}={'T' if v else 'F'}" for k, v in parts.items()))
    print(f"   not_here: {rec.get('not_here')}")
    pins = rec.get("PINS", {})
    print(f"   pins {pins.get('pins')}: at r19b {pins.get('at_r19b')}, read {len(pins.get('read_here', []))}, unread "
          f"{len(pins.get('unread', []))}; backend admissible {pins.get('backend', {}).get('admissible')}")
    nl = rec.get(NL)
    if nl:
        s = nl["summary"]
        print(f"   NL-1: ok {nl['ok']}  forks {s['forks']}  instances {s['slot_instances']}  G {s['gates']}  T-0 {s['T0']}  "
              f"E-0 {s['E0']}  T-0 control {s['T0_control_fires']}  ({nl['seconds']} s)")
        for k, v in s["per_mode"].items():
            print(f"      {k}: F-0 {v['F0']}  S1 {v['S1']}  S4 {v['S4']}")
        print(f"      S3 {s['S3']};  S3 all 23 slots {s['S3_all_23_slots']};  budget all 23 {s['budget_all_23_slots']}  "
              f"(worst L {nl['all_23_slots_S3_and_budget']['worst_L']})")
        print(f"      S5 {s['S5']}  ok {s['S5_ok']};  D55 controls {s['D55_controls']}")
    pre = rec.get(PRE)
    if pre:
        d = pre["d55"]
        print(f"   PRE: ok {pre['ok']}  exhibited {len(pre['exhibited'])}/{len(pre['commitments'])}  entries "
              f"{pre['view_entries_compared']:,} differing {pre['view_entries_differing']}  leaves {pre['salted_leaves_authenticated']}  "
              f"d55 findings {d['findings']}  ({pre['seconds']} s)")
        for r in d["per_commitment"]:
            print(f"      {r['commitment']:9s} rows {r['rows']:5d} data {r['data_rows']:5d} groups {r['groups']:3d} claims {r['claims']:4d} "
                  f"n {r['msg_n']} Q {r['pad_Q']} d {r['distinct_opened_columns']} entries {r['entries_compared']:,} "
                  f"diff {r['entries_differing']} leaves {r['salted_leaves_authenticated']}/{r['opened_columns']} fibre {r['fibre_dimension_fp']:,} "
                  f"({r['seconds']} s)")
        c = pre.get("controls", {})
        print(f"      ah_controls on {c.get('on')}: fire {c.get('controls_that_fire')}/{c.get('controls_total')}, applicable "
              f"{c.get('controls_applicable')}, not applicable {c.get('not_applicable')}  ({c.get('seconds')} s)")
        for x in c.get("controls", []):
            print(f"         {x['control']}: fires {x.get('fires')}  {(x.get('refusal') or x.get('skipped') or '')[:110]}")
        dc = pre.get("d55_controls", {})
        for k, v in dc.items():
            if isinstance(v, dict):
                print(f"         {k}: fires {v.get('fires')}  {(v.get('refusal') or '')[:110]}")
    vs = verdicts(rec)
    n_f = sum(1 for _n, f in vs if f)
    n_na = [n for n, f in vs if f is None]
    print(f"   control verdicts in the record: {len(vs)}; fire {n_f}; not run / not applicable {len(n_na)} {n_na[:4]}; "
          f"do NOT fire {[n for n, f in vs if f is False]}")
    total_ctl += len(vs)
    fired_ctl += n_f
    na_ctl += n_na
print(f"TOTAL control verdicts {total_ctl}; fire {fired_ctl}; not run / not applicable {len(na_ctl)}")
