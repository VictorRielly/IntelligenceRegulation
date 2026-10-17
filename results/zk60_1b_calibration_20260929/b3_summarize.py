#!/usr/bin/env python3
"""Lane B3: the ladder table from runs/b3_<name>/{summary,layer_NN}.json.
Pure file reading. Usage: b3_summarize.py name1 name2 ... [--json out.json]"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent


def load(name):
    d = HERE / "runs" / f"b3_{name}"
    s = json.loads((d / "summary.json").read_text())
    layers = [json.loads(p.read_text()) for p in sorted(d.glob("layer_*.json"))]
    return s, layers


def row(name):
    s, layers = load(name)
    ha, hd = s.get("head_accepted") or {}, s.get("head_all_diagnostic") or {}
    clip = {}
    for e in layers:
        for k, v in e["solve"].get("weights_clipped", {}).items():
            clip[k] = clip.get(k, 0) + v
    refuse_sites = {}
    for e in layers:
        for k, v in e["chained"]["range"]["sites"].items():
            if v["violations"]:
                refuse_sites[f"L{e['layer']:02d} {k}"] = v["seqs_refused"]
    site = {}
    for e in layers:
        for k, v in e.get("site_rel_error_isolated", {}).items():
            if k != "refused_sequences":
                site.setdefault(k, []).append(v)
    return {
        "name": name, "profile": s["profile"],
        "heldout_sequences": len(s["heldout_sequences"]), "calib_sequences": len(s["calib_sequences"]),
        "heldout_refused": s["heldout_refused"], "calib_refused": s["calib_refused"],
        "top1_accepted": ha.get("top1_agreement"), "ppl_float_accepted": ha.get("ppl_float"), "ppl_int_accepted": ha.get("ppl_int"),
        "kl_accepted": ha.get("kl_float_to_int_mean"), "positions_accepted": ha.get("positions"),
        "top1_all": hd.get("top1_agreement"), "ppl_float_all": hd.get("ppl_float"), "ppl_int_all": hd.get("ppl_int"),
        "kl_all": hd.get("kl_float_to_int_mean"),
        "embedding_cos_mean": s["embedding_cos"]["mean"],
        "iso_cos": [round(e["isolated"]["cos"]["mean"], 4) for e in layers],
        "iso_dcos": [round(e["isolated"]["delta_cos"]["mean"], 4) for e in layers],
        "chain_cos": [round(e["chained"]["cos"]["mean"], 4) for e in layers],
        "site_rel_err_median_over_layers": {k: round(float(np.median(v)), 3) for k, v in site.items()},
        "weights_clipped_total": {k: v for k, v in clip.items() if v},
        "refusals_heldout_chained": refuse_sites,
        "constants_by_layer": [{k: e["constants"][k] for k in ("norm_cn_a", "norm_cn_m", "norm_ceps", "exp_e_s", "silu_member",
                                                               "sh_qkv", "sh_s", "sh_ao", "sh_g", "sh_h", "sh_z", "sh_r2")} for e in layers],
    }


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    out = None
    if "--json" in sys.argv:
        out = sys.argv[sys.argv.index("--json") + 1]
        args = [a for a in args if a != out]
    rows = [row(n) for n in args]
    f = lambda v, p=3: "-" if v is None else (f"{v:.{p}f}" if isinstance(v, float) else str(v))
    print(f"{'variant':16s} {'top1 acc':>8s} {'ppl f/i (acc)':>16s} {'KL acc':>7s} {'top1 all':>8s} {'ppl i all':>9s} "
          f"{'ref h/c':>9s} {'emb cos':>7s} {'iso cos mean':>12s} {'chain L21':>9s}")
    for r in rows:
        print(f"{r['name']:16s} {f(r['top1_accepted']):>8s} {f(r['ppl_float_accepted'], 2) + '/' + f(r['ppl_int_accepted'], 2):>16s} "
              f"{f(r['kl_accepted']):>7s} {f(r['top1_all']):>8s} {f(r['ppl_int_all'], 2):>9s} "
              f"{str(r['heldout_refused']) + '/' + str(r['heldout_sequences']) + ' ' + str(r['calib_refused']):>9s} "
              f"{f(r['embedding_cos_mean'], 4):>7s} {f(float(np.mean(r['iso_cos'])), 4):>12s} {f(r['chain_cos'][-1], 4):>9s}")
    for r in rows:
        print(f"\n== {r['name']}: profile {json.dumps({k: v for k, v in r['profile'].items() if k not in ('s_in', 's_out')})}")
        print(f"   s_in {['%.3g' % v for v in r['profile']['s_in']]}")
        print(f"   chain cos {r['chain_cos']}")
        print(f"   iso dcos  {r['iso_dcos']}")
        print(f"   site err (median over layers) {r['site_rel_err_median_over_layers']}")
        print(f"   clipped {r['weights_clipped_total']}  refusals {r['refusals_heldout_chained']}")
    if out:
        Path(out).write_text(json.dumps(rows, indent=1))


if __name__ == "__main__":
    main()
