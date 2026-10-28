"""Compare last-position logits between two runs (npz with 'logits' and 'names').

python3 -I compare.py A.npz B.npz OUT.json [labelA labelB]
Reports per shared prompt: max |logit_A - logit_B| over the 131,072-token vocabulary, the yes/no
margin in each run and its difference, argmax / top-20 agreement, and the logit scale (max |logit|).
"""
import json
import sys

sys.path.append("/home/victor/.local/lib/python3.10/site-packages")
import numpy as np  # noqa: E402

YES, NO = 13059, 2649


def main():
    a, b = np.load(sys.argv[1]), np.load(sys.argv[2])
    la, lb = (sys.argv[4], sys.argv[5]) if len(sys.argv) > 5 else ("A", "B")
    ia = {str(n): i for i, n in enumerate(a["names"])}
    ib = {str(n): i for i, n in enumerate(b["names"])}
    rows = []
    for n in ia:
        if n not in ib:
            continue
        x, y = a["logits"][ia[n]].astype(np.float64), b["logits"][ib[n]].astype(np.float64)
        d = np.abs(x - y)
        mx, my = x[YES] - x[NO], y[YES] - y[NO]
        t20x, t20y = set(np.argsort(-x)[:20]), set(np.argsort(-y)[:20])
        rows.append({"name": n, "max_abs_logit_diff": float(d.max()), "mean_abs_logit_diff": float(d.mean()),
                     "argmax_token_of_max_diff": int(d.argmax()),
                     "abs_diff_yes": float(d[YES]), "abs_diff_no": float(d[NO]),
                     f"margin_{la}": float(mx), f"margin_{lb}": float(my), "margin_diff": float(mx - my),
                     "logit_scale_max_abs": float(np.abs(x).max()),
                     "argmax_equal": bool(x.argmax() == y.argmax()), "top20_equal": t20x == t20y})
    summ = {"A": sys.argv[1], "B": sys.argv[2], "labelA": la, "labelB": lb, "n": len(rows),
            "max_abs_logit_diff_over_all": max(r["max_abs_logit_diff"] for r in rows),
            "max_abs_margin_diff": max(abs(r["margin_diff"]) for r in rows), "rows": rows}
    if "layer_last" in a.files and "layer_last" in b.files:
        summ["layer_last_max_abs_diff"] = float(np.abs(a["layer_last"] - b["layer_last"]).max())
    json.dump(summ, open(sys.argv[3], "w"), indent=1)
    for r in rows:
        print(f"{r['name']:16s} max|dlogit|={r['max_abs_logit_diff']:.3e} margin {la}={r[f'margin_{la}']:+.5f} "
              f"{lb}={r[f'margin_{lb}']:+.5f} d={r['margin_diff']:+.2e} argmax_eq={r['argmax_equal']} "
              f"top20_eq={r['top20_equal']} scale={r['logit_scale_max_abs']:.1f}")
    print("overall max |dlogit| =", summ["max_abs_logit_diff_over_all"], " max |dmargin| =", summ["max_abs_margin_diff"])


if __name__ == "__main__":
    main()
