#!/usr/bin/env python3
"""L2 run 2: the steady gap per pass and its pairs against the base arm.

usage: l2_steady.py <label> <base arm>

For a pass of R requests (q = 0..R-1), with l2_terms.py's REQ regex:
  steady gap   (result[R-2] - result[1]) / (R-3): leaves out the first gap and the last request (nothing beside it)
  cadence      (result[R-1] - result[0]) / (R-1): the earlier runs' measure, for reference
Also medians over the passes of the prove call, the sealing pass and the prover wait by request index.
Pairs: the arm's steady gap minus the base arm's in the same pass; "pos" is the place of arm/base in that pass.
Prints and writes L2_STEADY_<label>.md.
"""
import statistics as st
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from l2_terms import REQ  # noqa: E402


def main() -> int:
    label, base = sys.argv[1], sys.argv[2]
    text = (HERE / "raw" / f"{label}.log").read_text(errors="replace")
    reqs, order = {}, {}
    for m in REQ.finditer(text):
        g = m.groupdict()
        arm, p, q = g["arm"], int(g["p"]), int(g["q"])
        reqs[(arm, p, q)] = {k: float(v) for k, v in g.items() if k not in ("arm", "p", "q")}
        order.setdefault(p, [])
        if arm not in order[p]:
            order[p].append(arm)
    passes = sorted(order)
    arms = []
    for p in passes:
        for a in order[p]:
            if a not in arms:
                arms.append(a)
    nreq = {a: 1 + max(q for (x, _, q) in reqs if x == a) for a in arms}
    out = [f"### L2 {label}: {len(reqs)} request lines; requests per pass {nreq}; passes {passes}", ""]
    out.append("arm order per pass: " + "; ".join(f"{p}: {' > '.join(order[p])}" for p in passes))
    out.append("")
    steady, cad = {}, {}
    for a in arms:
        r_ = nreq[a]
        for p in passes:
            if any((a, p, q) not in reqs for q in range(r_)):
                continue
            res = [reqs[(a, p, q)]["res"] for q in range(r_)]
            steady[(a, p)] = (res[r_ - 2] - res[1]) / (r_ - 3)
            cad[(a, p)] = (res[r_ - 1] - res[0]) / (r_ - 1)
    for name, d in (("steady gap", steady), ("cadence", cad)):
        out.append(f"| {name} per pass (s) | " + " | ".join(f"pass {p}" for p in passes) + " | median | min-max |")
        out.append("|---|" + "---|" * (len(passes) + 2))
        for a in arms:
            v = [d.get((a, p)) for p in passes]
            w = [x for x in v if x is not None]
            out.append(f"| {a} | " + " | ".join("-" if x is None else f"{x:.3f}" for x in v) + f" | {st.median(w):.3f} | {min(w):.3f}-{max(w):.3f} |")
        out.append("")
    for name, d in (("steady gap", steady), ("cadence", cad)):
        out.append(f"Pairs by pass against `{base}` on the {name} (arm minus base, s; negative = the arm is faster; pos arm/base):")
        out.append("")
        out.append("| arm | " + " | ".join(f"pass {p}" for p in passes) + " | median diff | median % | lower in |")
        out.append("|---|" + "---|" * (len(passes) + 3))
        for a in arms:
            if a == base:
                continue
            cells, dd = [], []
            for p in passes:
                if (a, p) in d and (base, p) in d:
                    x = d[(a, p)] - d[(base, p)]
                    dd.append((x, d[(base, p)]))
                    cells.append(f"{x:+.3f} ({order[p].index(a) + 1}/{order[p].index(base) + 1})")
                else:
                    cells.append("-")
            out.append(f"| {a} | " + " | ".join(cells) + f" | {st.median([x for x, _ in dd]):+.3f} | "
                       f"{st.median([100 * x / b for x, b in dd]):+.2f}% | {sum(1 for x, _ in dd if x < 0)} of {len(dd)} |")
        out.append("")
    for key, name in (("pc", "prove call"), ("forks", "forks"), ("com", "commit"), ("seal", "sealing pass"), ("wait", "prover wait")):
        rmax = max(nreq.values())
        out.append(f"| {name} by request (s, median over passes) | " + " | ".join(f"q{q}" for q in range(rmax)) + " |")
        out.append("|---|" + "---|" * rmax)
        for a in arms:
            cells = []
            for q in range(rmax):
                v = [reqs[(a, p, q)][key] for p in passes if (a, p, q) in reqs]
                cells.append(f"{st.median(v):.3f}" if v else "-")
            out.append(f"| {a} | " + " | ".join(cells) + " |")
        out.append("")
    textout = "\n".join(out)
    print(textout)
    (HERE / f"L2_STEADY_{label}.md").write_text(textout + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
