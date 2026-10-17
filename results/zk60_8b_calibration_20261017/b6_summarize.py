#!/usr/bin/env python3
"""B6-2 summary: layer-1 options on the same 36 FineWeb held-out sequences (T=32, B5's T=32 calibration
and profile). Reads runs/*/summary.json + layer_*.json; writes runs/b6_l1_summary.json; prints a table.
The whole-model 'none' numbers are B5 T=32's FineWeb domain (same words, same sequences, per-sequence
chains); the layer-1 'none' numbers come from the 2-layer run b6l1none on the same sequences."""
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
R = HERE / "runs"
RUNS = {"none": "llama3_8b_pg_rot1_b6l1none_T32_L2smoke", "s0m": "llama3_8b_pg_rot1_b6l1s0m_T32",
        "m2zero": "llama3_8b_pg_rot1_b6l1m2zero_T32", "perhead": "llama3_8b_pg_rot1_b6l1perhead_T32",
        "s16": "llama3_8b_pg_rot1_b6l1s16_T32",
        "scr_sh7": "llama3_8b_pg_rot1_b6l1scrsh7_T32_L2smoke", "scr_o16": "llama3_8b_pg_rot1_b6l1scro16_T32_L2smoke",
        "scr_sh7o16": "llama3_8b_pg_rot1_b6l1scrsh7o16_T32_L2smoke"}
B5_T32 = R / "llama3_8b_pg_rot1_T32"


def layer(run, l):
    p = R / run / f"layer_{l:02d}.json"
    return json.loads(p.read_text()) if p.exists() else None


def head(s):
    h = s["by_domain"]["fineweb-edu"]
    return {"refused": h["refused"], "accepted": h["head_accepted"], "all_diagnostic": h["head_all_diagnostic"]}


out = {}
for opt, run in RUNS.items():
    l1 = layer(run, 1)
    if l1 is None:
        out[opt] = {"missing": run}
        continue
    sp = R / run / "summary.json"
    s = json.loads(sp.read_text()) if sp.exists() else None
    last = max(int(p.stem.split("_")[1]) for p in (R / run).glob("layer_*.json"))
    ll = layer(run, last)
    so = l1["solve"]
    e = {"run": run, "layer1": {
            "e_s": l1["constants"]["exp_e_s"], "sh_s": l1["constants"]["sh_s"], "silu": l1["constants"]["silu_member"],
            "perhead_e_s": so.get("perhead", {}).get("e_s"),
            "iso_cos_mean": l1["isolated"]["cos"]["mean"], "iso_dcos_mean": l1["isolated"]["delta_cos"]["mean"],
            "iso_seqs": l1["isolated"]["sequences"], "chain_cos_mean": l1["chained"]["cos"]["mean"],
            "site_rel_err": {k: l1["site_rel_error_isolated"].get(k) for k in ("q", "k", "score", "prob", "o", "ao", "update")}},
         "layer0_chain_cos_mean": layer(run, 0)["chained"]["cos"]["mean"],
         "last_layer": last, "last_chain_cos_mean": ll["chained"]["cos"]["mean"],
         "chain_cos_by_layer": [layer(run, l)["chained"]["cos"]["mean"] for l in range(last + 1)]}
    if s:
        e["heldout_refused"] = s["heldout_refused"]
        e["first_refusals"] = [f for f in s["heldout_first_refusal"] if f]
        e["words_vs_B5_T32_export"] = s["check_against"]
        if "by_domain" in s:
            e["head_fineweb"] = head(s)
        e["seconds"] = s["seconds"]
    out[opt] = e
b5 = json.loads((B5_T32 / "summary.json").read_text())
out["none"]["head_fineweb_from_B5_T32"] = head(b5)
(R / "b6_l1_summary.json").write_text(json.dumps(out, indent=1))

print(f"{'option':8} {'e_s':>14} {'iso cos':>8} {'dcos':>6} {'chain L1':>8} {'chain last':>10} {'refused':>7} "
      f"{'top1':>6} {'ppl_int':>8} {'KL':>6} | site score prob o")
for opt, e in out.items():
    if "missing" in e:
        print(f"{opt:8} MISSING {e['missing']}")
        continue
    l1 = e["layer1"]
    h = e.get("head_fineweb") or e.get("head_fineweb_from_B5_T32")
    a = (h["accepted"] or h["all_diagnostic"]) if h else {}       # accepted is None when every sequence refused
    if h and h["accepted"] is None:
        opt = opt + "*"                                              # * = diagnostic only (all refused, clamped)
    es = l1["perhead_e_s"] and f"{min(l1['perhead_e_s'])}..{max(l1['perhead_e_s'])}" or str(l1["e_s"])
    print(f"{opt:8} {es:>14} {l1['iso_cos_mean']:8.4f} {l1['iso_dcos_mean']:6.3f} {l1['chain_cos_mean']:8.4f} "
          f"{e['last_chain_cos_mean']:10.4f}(L{e['last_layer']}) {str(e.get('heldout_refused', h and h['refused'])):>4} "
          f"{a.get('top1_agreement', float('nan')):6.3f} {a.get('ppl_int', float('nan')):8.2f} {a.get('kl_float_to_int_mean', float('nan')):6.3f} | "
          f"{l1['site_rel_err']['score']:.3f} {l1['site_rel_err']['prob']:.3f} {l1['site_rel_err']['o']:.3f}")
    if e.get("words_vs_B5_T32_export"):
        print(f"         words vs B5 export: {e['words_vs_B5_T32_export']['layers_with_different_words']}")
