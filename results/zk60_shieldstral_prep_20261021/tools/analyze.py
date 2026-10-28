"""Metrics from bench/*.jsonl -> bench/metrics.json (+ printed tables).

python3 -I analyze.py [--limit N]   (--limit restricts each file to its first N items in selection order,
                                      i.e. the seeded subset; default: all rows present)
Verdict rules:
  d38: unsafe iff z_yes - z_no > 0  (score = sigmoid(margin) > 0.5; the D38 statement, tokens 'yes'/'no')
  ref: Mistral cookbook scorer: max log-prob over yes / no variants within the top-20, score > 0.5
"""
import glob
import json
import os
import sys

sys.path.append("/home/victor/.local/lib/python3.10/site-packages")
import numpy as np  # noqa: E402

LANE = "/home/victor/IntelligenceRegulation/results/zk60_shieldstral_prep_20261021"
DELTAS = [0.05, 0.1, 0.25, 0.5, 1.0, 2.0, 4.0]


def prf(y, p):
    tp = int(np.sum((p == 1) & (y == 1)))
    fp = int(np.sum((p == 1) & (y == 0)))
    fn = int(np.sum((p == 0) & (y == 1)))
    tn = int(np.sum((p == 0) & (y == 0)))
    prec = tp / (tp + fp) if tp + fp else float("nan")
    rec = tp / (tp + fn) if tp + fn else float("nan")
    f1 = 2 * tp / (2 * tp + fp + fn) if tp + fp + fn else float("nan")
    return {"tp": tp, "fp": fp, "fn": fn, "tn": tn, "precision": prec, "recall": rec, "f1": f1}


def boot_f1(y, p, n=2000, seed=0):
    rng = np.random.default_rng(seed)
    idx = rng.integers(0, len(y), size=(n, len(y)))
    yy, pp = y[idx], p[idx]
    tp = ((pp == 1) & (yy == 1)).sum(1)
    fp = ((pp == 1) & (yy == 0)).sum(1)
    fn = ((pp == 0) & (yy == 1)).sum(1)
    f1 = 2 * tp / np.maximum(1, 2 * tp + fp + fn)
    return [float(np.percentile(f1, 2.5)), float(np.percentile(f1, 97.5))]


def q(a):
    a = np.asarray(a, np.float64)
    ps = [0, 1, 5, 10, 25, 50, 75, 90, 95, 99, 100]
    return {f"p{p}": float(np.percentile(a, p)) for p in ps} | {"mean": float(a.mean()), "n": int(a.size)}


def main():
    limit = int(sys.argv[sys.argv.index("--limit") + 1]) if "--limit" in sys.argv else None
    out = {"limit": limit, "files": {}}
    for path in sorted(glob.glob(f"{LANE}/bench/*.jsonl")):
        rows = [json.loads(line) for line in open(path)]
        if limit:
            rows = rows[:limit]
        if not rows:
            continue
        y = np.array([r["label"] for r in rows])
        mg = np.array([r["margin"] for r in rows])
        p38 = (mg > 0).astype(int)
        pref = np.array([1 if r["ref_score"] > 0.5 else 0 for r in rows])
        am = np.array([r["argmax"] for r in rows])
        nct = np.array([r["n_content_tokens"] for r in rows])
        rec = {"n": len(rows), "positives": int(y.sum()),
               "d38": prf(y, p38) | {"f1_ci95_bootstrap": boot_f1(y, p38)},
               "ref": prf(y, pref) | {"f1_ci95_bootstrap": boot_f1(y, pref)},
               "rule_disagreements": int(np.sum(p38 != pref)),
               "margin_all": q(mg), "margin_label1": q(mg[y == 1]) if y.sum() else None,
               "margin_label0": q(mg[y == 0]) if (y == 0).sum() else None,
               "abs_margin": q(np.abs(mg)),
               "frac_abs_margin_below": {str(d): float(np.mean(np.abs(mg) < d)) for d in DELTAS},
               "count_abs_margin_below": {str(d): int(np.sum(np.abs(mg) < d)) for d in DELTAS},
               "argmax_is_yes_or_no": float(np.mean((am == 13059) | (am == 2649))),
               "p_yes_plus_no": q([r["p_yes_plus_no"] for r in rows]),
               "content_tokens": q(nct), "T_total": q([r["T"] for r in rows])}
        # thresholds sweep (diagnostic only: tuned on the test set, not a claim)
        best = max(((t, prf(y, (mg > t).astype(int))["f1"]) for t in np.arange(-6, 6.01, 0.25)),
                   key=lambda z: z[1])
        rec["diagnostic_best_threshold_on_margin"] = {"t": float(best[0]), "f1": best[1]}
        out["files"][os.path.basename(path)] = rec
        d, r_ = rec["d38"], rec["ref"]
        print(f"{os.path.basename(path):28s} n={rec['n']:5d} pos={rec['positives']:4d} "
              f"D38: P={d['precision']:.3f} R={d['recall']:.3f} F1={d['f1']:.3f} CI{d['f1_ci95_bootstrap']} | "
              f"ref F1={r_['f1']:.3f} disagree={rec['rule_disagreements']} | "
              f"|m|<0.5: {rec['count_abs_margin_below']['0.5']} |m|<1: {rec['count_abs_margin_below']['1.0']} "
              f"median|m|={rec['abs_margin']['p50']:.2f}")
    suffix = f"_first{limit}" if limit else ""
    json.dump(out, open(f"{LANE}/bench/metrics{suffix}.json", "w"), indent=1)
    print("wrote", f"{LANE}/bench/metrics{suffix}.json")


if __name__ == "__main__":
    main()
