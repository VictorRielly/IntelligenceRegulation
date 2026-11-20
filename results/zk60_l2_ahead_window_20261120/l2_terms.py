#!/usr/bin/env python3
"""L2: per-arm terms of the stream A/B from one log, paired by pass against the base arm.

usage: l2_terms.py <label> [base arm, default serve4]

Definitions are those of results/zk60_a33_seal_dedup_20261117/serve4_terms.py (its REQ regex; q = request index in a
pass of 4 requests at two lanes):
  cadence      (result[3]-result[0])/3 per pass (the steady cadence)
  prove call   pc, q>=1; forks, commit: phases inside it, q>=1
  sealing ov   the sealing pass of requests 1..3 (beside a proof); sealing solo: request 0
  admission    sealing turn(q) - sealing done(q-1), q>=2 (the lane admission wait)
  prover wait  prover start - sealing done, q>=1
  result gap   result[q]-result[q-1], q>=1
Pairs: for every pass, the arm's cadence against the base arm's cadence in the SAME pass; "pos" is the arm's place in
that pass (the order is reversed in odd passes). Prints a table and writes L2_TERMS_<label>.md beside this script.
"""
import re
import statistics as st
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REQ = re.compile(
    r"A22-AB REQ \S+ L32 N6 \[(?P<arm>[^\]]+)\] pass (?P<p>\d+) request (?P<q>\d+): "
    r"arrived (?P<arr>[0-9.]+), sealing turn (?P<turn>[0-9.]+), sealing side done (?P<sdone>[0-9.]+) \(sealing pass (?P<seal>[0-9.]+) s\), "
    r"prover (?P<ps>[0-9.]+)-(?P<pe>[0-9.]+) \(waited (?P<wait>[0-9.]+) s; prove call (?P<pc>[0-9.]+) s: "
    r"preflight (?P<pre>[0-9.]+), commit (?P<com>[0-9.]+), forks (?P<forks>[0-9.]+), join (?P<join>[0-9.]+)\), "
    r"receipt write (?P<w>[0-9.]+) s \([^)]*\), result (?P<res>[0-9.]+);")
KEYS = ["cadence", "prove call", "forks", "commit", "join", "sealing ov", "sealing solo", "admission", "prover wait", "result gap"]


def main() -> int:
    label = sys.argv[1]
    base = sys.argv[2] if len(sys.argv) > 2 else "serve4"
    text = (HERE / "raw" / f"{label}.log").read_text(errors="replace")
    reqs, order = {}, {}
    for m in REQ.finditer(text):
        g = m.groupdict()
        arm, p, q = g["arm"], int(g["p"]), int(g["q"])
        reqs[(arm, p, q)] = {k: float(v) for k, v in g.items() if k not in ("arm", "p", "q")}
        order.setdefault(p, [])
        if arm not in order[p]:
            order[p].append(arm)
    arms = []
    for p in sorted(order):
        for a in order[p]:
            if a not in arms:
                arms.append(a)
    passes = sorted(order)
    T = {a: {k: [] for k in KEYS} for a in arms}
    cad = {}
    for a in arms:
        for p in passes:
            if any((a, p, q) not in reqs for q in range(4)):
                continue
            r = [reqs[(a, p, q)] for q in range(4)]
            c = (r[3]["res"] - r[0]["res"]) / 3
            cad[(a, p)] = c
            T[a]["cadence"].append(c)
            T[a]["sealing solo"].append(r[0]["seal"])
            for q in range(1, 4):
                T[a]["prove call"].append(r[q]["pc"])
                T[a]["forks"].append(r[q]["forks"])
                T[a]["commit"].append(r[q]["com"])
                T[a]["join"].append(r[q]["join"])
                T[a]["sealing ov"].append(r[q]["seal"])
                T[a]["prover wait"].append(r[q]["wait"])
                T[a]["result gap"].append(r[q]["res"] - r[q - 1]["res"])
                if q >= 2:
                    T[a]["admission"].append(max(0.0, r[q]["turn"] - r[q - 1]["sdone"]))
    out = [f"### L2 {label}: {len(reqs)} request lines, arms {arms}, passes {passes}", ""]
    out.append("arm order per pass: " + "; ".join(f"{p}: {' > '.join(order[p])}" for p in passes))
    out.append("")
    out.append("| term (s, median) | " + " | ".join(arms) + " |")
    out.append("|---|" + "---|" * len(arms))
    for k in KEYS:
        out.append(f"| {k} | " + " | ".join(f"{st.median(T[a][k]):.3f} (n={len(T[a][k])})" if T[a][k] else "-" for a in arms) + " |")
    out.append("")
    out.append("| cadence per pass (s) | " + " | ".join(f"pass {p}" for p in passes) + " | median | min-max |")
    out.append("|---|" + "---|" * (len(passes) + 2))
    for a in arms:
        v = [cad.get((a, p)) for p in passes]
        w = [x for x in v if x is not None]
        out.append(f"| {a} | " + " | ".join("-" if x is None else f"{x:.3f}" for x in v) + f" | {st.median(w):.3f} | {min(w):.3f}-{max(w):.3f} |")
    out.append("")
    out.append(f"Pairs by pass against `{base}` (arm minus base, s; negative = the arm is faster):")
    out.append("")
    out.append("| arm | " + " | ".join(f"pass {p} (pos {{}})".replace("{}", "arm/base") for p in passes) + " | median diff | median % | lower in |")
    out.append("|---|" + "---|" * (len(passes) + 3))
    for a in arms:
        if a == base:
            continue
        cells, d = [], []
        for p in passes:
            if (a, p) in cad and (base, p) in cad:
                x = cad[(a, p)] - cad[(base, p)]
                d.append((x, cad[(base, p)]))
                cells.append(f"{x:+.3f} ({order[p].index(a) + 1}/{order[p].index(base) + 1})")
            else:
                cells.append("-")
        md = st.median([x for x, _ in d])
        mp = st.median([100 * x / b for x, b in d])
        out.append(f"| {a} | " + " | ".join(cells) + f" | {md:+.3f} | {mp:+.2f}% | {sum(1 for x, _ in d if x < 0)} of {len(d)} |")
    out.append("")
    b = T[base]
    for a in arms:
        if a == base:
            continue
        out.append(f"`{a}` minus `{base}` (medians): " + ", ".join(
            f"{k} {st.median(T[a][k]) - st.median(b[k]):+.3f}" for k in KEYS if T[a][k] and b[k]))
    textout = "\n".join(out)
    print(textout)
    (HERE / f"L2_TERMS_{label}.md").write_text(textout + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
