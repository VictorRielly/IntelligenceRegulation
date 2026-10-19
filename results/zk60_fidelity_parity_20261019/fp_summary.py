#!/usr/bin/env python3
"""Collect every fp_eval run into results_summary.json (machine-readable evidence) and merge
chunked LAMBADA runs: python3 fp_summary.py [--lambada MODEL TAG1,TAG2,... NAME]

Per run: model, export, relax set, what-ifs, per-corpus ppl float / int / ratio with CI,
top-1, KL, refusals, LAMBADA accuracies; gap closed vs the model's baseline run (abl_base)
on the same corpora."""
import json
import math
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent


def merge_lambada(model, tags, name):
    """Item-level merge of chunked LAMBADA runs (disjoint items)."""
    acc_f, acc_i, nf, ni, items, refused = [], [], [], [], [], 0
    for t in tags:
        d = HERE / "runs" / model / t
        s = json.loads((d / "summary.json").read_text())
        p = np.load(d / "per_position.npz")
        seq, af, ai, tg = p["seq"], p["arg_f"], p["arg_i"], p["tgt"]
        for i in np.unique(seq):
            m = seq == i
            acc_f.append(bool(np.all(af[m] == tg[m])))
            acc_i.append(bool(np.all(ai[m] == tg[m])))
            nf.append(float(p["nll_f"][m].sum()))
            ni.append(float(p["nll_i"][m].sum()))
        refused += s["refused"]
        items.append(s["corpora"]["corpora"]["lambada"])
    a_f, a_i = np.array(acc_f, float), np.array(acc_i, float)
    dd = a_i - a_f
    n = len(dd)
    se = dd.std(ddof=1) / math.sqrt(n)
    sef = a_f.std(ddof=1) / math.sqrt(n)
    out = {"model": model, "runs": tags, "items": n, "chunks": items, "acc_float": a_f.mean(), "acc_float_ci95": [a_f.mean() - 1.96 * sef, a_f.mean() + 1.96 * sef],
           "acc_int": a_i.mean(), "acc_diff": dd.mean(), "acc_diff_ci95": [dd.mean() - 1.96 * se, dd.mean() + 1.96 * se],
           "acc_ratio_int_over_float": a_i.mean() / a_f.mean(), "discordant": {"int_only": int((dd > 0).sum()), "float_only": int((dd < 0).sum())},
           "target_nll_float": float(np.mean(nf)), "target_nll_int": float(np.mean(ni)), "refused_sequences": refused}
    (HERE / "runs" / model / f"lambada_{name}.json").write_text(json.dumps(out, indent=1, default=float))
    print(json.dumps(out, indent=1, default=float))
    return out


def main():
    if "--lambada" in sys.argv:
        i = sys.argv.index("--lambada")
        merge_lambada(sys.argv[i + 1], sys.argv[i + 2].split(","), sys.argv[i + 3])
        return
    rows = []
    for model_dir in sorted((HERE / "runs").iterdir()):
        if not model_dir.is_dir():
            continue
        base = {}
        bp = model_dir / "abl_base" / "summary.json"
        if bp.exists():
            bs = json.loads(bp.read_text())
            base = {c: r["all"]["ppl_ratio"]["ratio"] for c, r in bs["metrics"].items() if "ppl_ratio" in r["all"]}
            base_ids = bs["corpora"]["ids_sha256"]
        for d in sorted(model_dir.iterdir()):
            sp = d / "summary.json"
            if not sp.exists():
                continue
            s = json.loads(sp.read_text())
            r = {"model": model_dir.name, "tag": d.name, "export": Path(s["export"]).name, "relax": s["relax"],
                 "mods": s.get("mods"), "gate_pc": (s.get("gate_pc") or {}).get("spec"), "gptq": bool(s.get("gptq")),
                 "refused": s["refused"], "seconds": round(s["seconds"]), "corpora": {}}
            for c, m in s["metrics"].items():
                al = m["all"]
                e = {"n": al["sequences"], "top1": al["top1_agreement"], "kl": al["kl_mean"], "refused": m["refused"]}
                if "ppl_ratio" in al:
                    e.update({"ppl_float": al["ppl_float"], "ppl_int": al["ppl_int"], "ratio": al["ppl_ratio"]["ratio"],
                              "ci95": al["ppl_ratio"]["ci95_t"]})
                    if c in base and base[c] > 1 and s["corpora"]["ids_sha256"] == base_ids:
                        e["gap_closed_vs_abl_base"] = 1 - math.log(e["ratio"]) / math.log(base[c])
                else:
                    e.update({"acc_float": al["acc_float"], "acc_int": al["acc_int"], "acc_diff": al["acc_diff"],
                              "acc_diff_ci95": al["acc_diff_ci95"]})
                r["corpora"][c] = e
            r["refusal_tokens"] = s.get("refusal_tokens", [])[:20]
            rows.append(r)
    (HERE / "results_summary.json").write_text(json.dumps(rows, indent=1, default=float))
    for r in rows:
        cs = " | ".join(f"{c} {e.get('ratio', e.get('acc_diff', 0)):.4f}" + (f" ({100 * e['gap_closed_vs_abl_base']:.0f}%)" if 'gap_closed_vs_abl_base' in e else "")
                        for c, e in r["corpora"].items())
        print(f"{r['model']:10s} {r['tag']:18s} {r['export'][:22]:22s} ref {r['refused']:3d} {cs}")


if __name__ == "__main__":
    main()
