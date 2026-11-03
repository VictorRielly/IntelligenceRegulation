#!/usr/bin/env python3
"""Per-bundle, per-slot S1-S5 tables (markdown) from fr25_17_nl1_all23.py records.
Usage: python3 summarize.py <record.json> [<record.json> ...]"""
import json
import sys

MODES = ("run", "random-1", "random-2", "random-3")


def yn(x):
    return "yes" if x is True else "NO" if x is False else "n/a" if x is None else str(x)


def one(path):
    d = json.load(open(path))
    w = d.get("NL-1 all 23 slots", {})
    s = w.get("summary", {})
    out = [f"### {d['bundle']} fork {d['fork']} (G {s.get('gates', {}).get(str(d['fork']))})", ""]
    out.append(f"record `{path.split('/')[-1]}`: status {'PASS' if d.get('ok') else 'NOT-OK'}; wall {d.get('total_seconds')} s "
               f"(phases {d.get('seconds')}); peak RSS {d.get('peak_rss_mib')} MiB")
    r3 = d.get("R13-3_on_fork") or {}
    out.append(f"R13-3 on the fork: {r3.get('slot_checks_equal')}/{r3.get('slot_checks_expected')}, G closing SC_FZC "
               f"{r3.get('gate_values_closing_sc_fzc')}")
    out.append("")
    out.append("| slot | name | set | main | ext | d | max deg | per-var | slack | L | S1 (4 modes) | S4 (4 modes) | T-0/E-0 | N5-1 | N5-2 | F-1 |")
    out.append("|---:|---|---|---:|---:|---:|---:|---:|---:|---:|---|---|---|---|---|---|")
    for r in w.get("per_slot", []):
        s1 = all(r[m]["S1"]["premise"] and r[m]["S1"]["public_factor_every_monomial"] and r[m]["S1"]["degree_fits"]
                 and r[m]["S1"]["budget_ok"] for m in MODES if m in r)
        s4 = all(r[m]["S4"]["miniature_passes"] and r[m]["S4"]["terminal_map_onto"] for m in MODES if m in r)
        nm = sum(1 for m in MODES if m in r)
        run = r["run"]["S1"]
        n51 = ("not fired, as predicted" if r["S5"]["N5_1_fires"] is False and r["S5"]["N5_1_as_predicted"]
               else yn(r["S5"]["N5_1_fires"]) + ("" if r["S5"]["N5_1_as_predicted"] else " (NOT as predicted)"))
        out.append(f"| {r['slot']} | {r['name'].split(' ', 1)[1]} | {'legacy-16' if r['set'].startswith('legacy') else 'NL-1 v25'} "
                   f"| {r['main']} | {r['extension']} | {r['declared_degree']} | {run['max_product_degree']} | "
                   f"{run['per_variable_bound']} | {run['slack']} | {run['L']} | {yn(s1)} ({nm}) | {yn(s4)} ({nm}) | "
                   f"{yn(r['T0'] and r['E0'] and r['T0_control_fires'])} | {n51} | {yn(r['S5']['N5_2_fires'])} | {yn(r['S5']['F_1_fires'])} |")
    out.append("")
    out.append(f"S3 Fact 2.1: {s.get('S3')}; all 23 slots of every fork: {s.get('S3_all_23_slots_every_fork')}, "
               f"budget {yn(s.get('budget_all_23_slots_every_fork'))}; split cross-check {s.get('extension_split_crosscheck')}")
    out.append(f"S5 raw (tokennl): {s.get('S5_tokennl_raw')}; adjudicated ok {yn(s.get('S5_adjudicated_ok'))}; "
               f"bilinear C1/C2/C3 ok {yn(s.get('bilinear_C1_C2_C3_ok'))}")
    out.append(f"S1 negative controls: {s.get('S1_negative_controls')}; D55 controls (23-slot contexts): {s.get('D55_controls')}")
    ca = d.get("control_a_seven_slots_reproduce", {})
    out.append("control (a): " + "; ".join(f"{k}: reproduces {yn(v.get('reproduces'))}, differences {v.get('differences')}"
                                          for k, v in ca.items())
               + f"; comparison self-test fires {yn(d.get('control_a_comparison_self_test', {}).get('fires'))}")
    out.append("")
    return "\n".join(out)


if __name__ == "__main__":
    print("\n".join(one(p) for p in sys.argv[1:]))
