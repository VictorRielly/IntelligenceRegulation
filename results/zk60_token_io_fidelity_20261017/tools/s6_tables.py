#!/usr/bin/env python3
"""s6: markdown tables for REPORT.md from data/s4_head.json (+ s3, s5). Small, single-threaded.
Usage: s6_tables.py [suffix]   (suffix "_smoke" reads the smoke outputs)."""

from __future__ import annotations

import json
import sys
from pathlib import Path

DATA = Path(__file__).resolve().parent.parent / "data"
suf = sys.argv[1] if len(sys.argv) > 1 else ""
H = json.loads((DATA / f"s4_head{suf}.json").read_text())


def pct(a):
    return "-" if a is None or a.get("rate") is None else f"{100 * a['rate']:.2f} % ({a['agree']}/{a['n']})"


fn = H["final_norm"]
print("## F1 constants\n")
print(f"* final norm: g0 {fn['g0']}, tn {fn['tn']}, Ceps {fn['ceps']}, window {fn['window_bits']} bits, Cn configs {fn['cn_configs']}")
print(f"* calibration |xhat'| max {fn['calib_xhat_rot_absmax']:.4f}; y reaches 127 at |xhat'| = "
      + ", ".join(f"{k} {v:.3f}" for k, v in fn["xhat_rot_at_which_y_reaches_127"].items()))
print(f"* head: {json.dumps(H['head'])}")
print(f"* fold check: {H['fold_check']}")
print(f"* selftests: {H['selftests']}\n")
S = H["summary"]
for T in [k for k in S if k.startswith("T")]:
    print(f"## {T}\n")
    print("| set | positions | float head vs float model | cfg | refused | int pt vs float head | int pr exact vs float head | int pt vs float model | ties | KL pt | KL pr |")
    print("|---|---:|---|---|---:|---|---|---|---:|---:|---:|")
    for sname, e in S[T].items():
        if sname == "details_cal":
            continue
        for cfg in fn["cn_configs"]:
            c = e[cfg]
            print(f"| {sname} | {e['positions']} | {pct(e['float_head_vs_float_model'])} | {cfg} | {c['refused_positions']} | "
                  f"{pct(c['int_pt_vs_float_head'])} | {pct(c['int_pr_exact_vs_float_head'])} | {pct(c['int_pt_vs_float_model'])} | "
                  f"{c['pt_tie_positions']} | {c['pt_kl_mean']:.5f} | {c['pr_exact_kl_mean']:.5f} |")
    print()
    c = S[T]["all"]["cal_m1.50"]
    print("per-row integer multipliers (cal cfg, all positions): "
          + ", ".join(f"b={k.split('_m')[1].split('_')[0]}: {pct(v)}" for k, v in c.items() if k.startswith("int_pr_m")))
    print()
    print("details (cal cfg):")
    print("```")
    print(json.dumps(S[T]["details_cal"], indent=1))
    print("```\n")
print("## pooled\n")
print("```")
print(json.dumps(S["pooled_T128_T32"], indent=1))
print("```")
