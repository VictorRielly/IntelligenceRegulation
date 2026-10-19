#!/usr/bin/env python3
"""Tabulate fp_eval runs: python3 fp_table.py MODEL BASE_TAG TAG [TAG ...] [--json OUT]

For every corpus: ppl float / int, ppl ratio with 95% CI, top-1 agreement,
KL, refusals; for LAMBADA accuracy float / int and the paired difference.
For each TAG also the share of the BASE run's log-ppl gap it closes
(gap closed = 1 - log(ratio_tag) / log(ratio_base)), paired per position
against the base run when both used the same corpora.
"""
import json
import math
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent


def load(model, tag):
    d = HERE / "runs" / model / tag
    s = json.loads((d / "summary.json").read_text())
    p = np.load(d / "per_position.npz")
    return s, p


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    jout = None
    if "--json" in sys.argv:
        jout = sys.argv[sys.argv.index("--json") + 1]
        args = [a for a in args if a != jout]
    model, base, tags = args[0], args[1], args[2:]
    sb, pb = load(model, base)
    rows = []
    for tag in [base] + tags:
        s, p = load(model, tag)
        for c, r in s["metrics"].items():
            al = r["all"]
            row = {"tag": tag, "relax": ",".join(s["relax"]) or "-", "corpus": c, "refused": r["refused"],
                   "top1": al["top1_agreement"], "kl": al["kl_mean"]}
            if c == "lambada":
                row.update({"acc_f": al["acc_float"], "acc_i": al["acc_int"], "acc_d": al["acc_diff"], "acc_ci": al["acc_diff_ci95"]})
            else:
                pr = al["ppl_ratio"]
                row.update({"ppl_f": al["ppl_float"], "ppl_i": al["ppl_int"], "ratio": pr["ratio"], "ci": pr["ci95_t"]})
                rb = sb["metrics"].get(c, {}).get("all", {}).get("ppl_ratio", {}).get("ratio")
                if rb and tag != base:
                    row["gap_closed"] = 1 - math.log(pr["ratio"]) / math.log(rb) if rb > 1 else None
                    if s["corpora"]["ids_sha256"] == sb["corpora"]["ids_sha256"]:
                        # paired change of the int model's per-sequence mean NLL vs the base run (this corpus)
                        corp = [m for m in s["corpora"]["corpora"]]
                        seqs = np.unique(p["seq"])
                        names = []
                        for cname in s["corpora"]["corpora"]:
                            names += [cname] * s["corpora"]["corpora"][cname]["n"]
                        sel = [i for i in seqs if names[i] == c]
                        ma = np.array([p["nll_i"][p["seq"] == i].mean() for i in sel])
                        mb = np.array([pb["nll_i"][pb["seq"] == i].mean() for i in sel])
                        dd = ma - mb
                        se = dd.std(ddof=1) / math.sqrt(len(dd))
                        lr = math.log(rb)
                        row["gap_closed_ci"] = [-(dd.mean() + 1.96 * se) / lr, -(dd.mean() - 1.96 * se) / lr]
            rows.append(row)
    hdr = f"{'tag':28s} {'corpus':9s} {'ppl_f':>7s} {'ppl_i':>7s} {'ratio':>7s} {'95% CI':>17s} {'closed':>7s} {'closed 95% CI':>13s} {'top1':>6s} {'KL':>6s} {'ref':>4s}"
    print(hdr)
    for r in rows:
        if r["corpus"] == "lambada":
            print(f"{r['tag']:28s} {r['corpus']:9s} acc_f {r['acc_f']:.4f} acc_i {r['acc_i']:.4f} diff {r['acc_d']:+.4f} "
                  f"CI [{r['acc_ci'][0]:+.4f},{r['acc_ci'][1]:+.4f}] top1 {r['top1']:.3f} KL {r['kl']:.4f} ref {r['refused']}")
        else:
            gc = r.get("gap_closed")
            gci = r.get("gap_closed_ci")
            print(f"{r['tag']:28s} {r['corpus']:9s} {r['ppl_f']:7.3f} {r['ppl_i']:7.3f} {r['ratio']:7.4f} "
                  f"[{r['ci'][0]:.4f},{r['ci'][1]:.4f}] {('%6.1f%%' % (100 * gc)) if gc is not None else '      -'} "
                  f"{('[%5.1f,%5.1f]' % (100 * gci[0], 100 * gci[1])) if gci else '             '} "
                  f"{r['top1']:6.3f} {r['kl']:6.4f} {r['refused']:4d}")
    if jout:
        Path(jout).write_text(json.dumps(rows, indent=1))


if __name__ == "__main__":
    main()
