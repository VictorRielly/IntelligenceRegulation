#!/usr/bin/env python3
"""A35 stage 4 analysis (results/zk60_l2_ahead_window_20261120/l2_steady.py and l2_terms.py, copied and adapted).

usage: a35_terms.py <label> [base arm, default serve8+lanes2] [arm, default serve8+lanes2+ba1]

From raw/<label>.log, per pass of R requests (q = 0..R-1), with l2_terms.py's REQ regex:
  steady gap   (result[R-2] - result[1]) / (R-3)   (R = 8: (result[6] - result[1]) / 5), as l2_steady.py
  cadence      (result[R-1] - result[0]) / (R-1), for reference
Per request index (median over passes): prove call (the call's own seconds; the A35 prover-turn wait inside it is
not counted), commit (its commit phase), forks, join, prover hold (prover left - prover entered), prover wait
(prover entered - sealing side done), sealing pass, and the prover-turn wait inside the call.
Footprint per arm from the STREAM lines (start, peak, end GiB).
THE RULE (fixed before the run, the task's): PASS if the arm's steady gap is lower than the base's in 6 of 6 passes
AND lower by at least 3% at the median of the per-pass relative differences; KILL if lower in fewer than 5 of 6, or
within 1% at the median; otherwise UNDECIDED.
Prints and writes A35_TERMS_<label>.md.
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
    r"receipt write (?P<w>[0-9.]+) s \([^)]*\), result (?P<res>[0-9.]+);"
    r".*?prover turn waited inside the call (?P<tw>[0-9.]+) s")
STREAM = re.compile(r"A22-AB STREAM \S+ L32 N6 \[(?P<arm>[^\]]+)\] pass (?P<p>\d+): .*?\(window (?P<win>\d+), .*?bounds ahead (?P<ba>\w+)\).*?"
                    r"footprint start (?P<f0>[0-9.]+) GiB, peak (?P<f1>[0-9.]+) GiB, end (?P<f2>[0-9.]+) GiB; user (?P<u>[0-9.]+) s \+ sys (?P<s>[0-9.]+) s")


def main() -> int:
    label = sys.argv[1]
    base = sys.argv[2] if len(sys.argv) > 2 else "serve8+lanes2"
    arm_b = sys.argv[3] if len(sys.argv) > 3 else "serve8+lanes2+ba1"
    text = (HERE / "raw" / f"{label}.log").read_text(errors="replace")
    reqs, order = {}, {}
    for m in REQ.finditer(text):
        g = m.groupdict()
        arm, p, q = g["arm"], int(g["p"]), int(g["q"])
        d = {k: float(v) for k, v in g.items() if k not in ("arm", "p", "q")}
        d["hold"] = d["pe"] - d["ps"]
        reqs[(arm, p, q)] = d
        order.setdefault(p, [])
        if arm not in order[p]:
            order[p].append(arm)
    streams = {}
    for m in STREAM.finditer(text):
        g = m.groupdict()
        streams[(g["arm"], int(g["p"]))] = g
    passes = sorted(order)
    arms = [base, arm_b]
    nreq = {a: 1 + max(q for (x, _, q) in reqs if x == a) for a in arms}
    out = [f"### A35 {label}: {len(reqs)} request lines; requests per pass {nreq}; passes {passes}", ""]
    out.append("arm order per pass: " + "; ".join(f"{p}: {' > '.join(order[p])}" for p in passes))
    out.append("")
    out.append("switches per arm as the STREAM lines print them (bounds ahead): " + "; ".join(
        f"{a}: {sorted(set(s['ba'] for (x, _), s in streams.items() if x == a))}, window {sorted(set(s['win'] for (x, _), s in streams.items() if x == a))}" for a in arms))
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
    verdict = None
    for name, d in (("steady gap", steady), ("cadence", cad)):
        out.append(f"Pairs by pass, `{arm_b}` minus `{base}` on the {name} (s; negative = the switch-on arm is faster; pos arm/base):")
        out.append("")
        out.append("| arm | " + " | ".join(f"pass {p}" for p in passes) + " | median diff | median % | lower in |")
        out.append("|---|" + "---|" * (len(passes) + 3))
        cells, dd = [], []
        for p in passes:
            if (arm_b, p) in d and (base, p) in d:
                x = d[(arm_b, p)] - d[(base, p)]
                dd.append((x, d[(base, p)]))
                cells.append(f"{x:+.3f} ({order[p].index(arm_b) + 1}/{order[p].index(base) + 1})")
            else:
                cells.append("-")
        md, mp, lower = st.median([x for x, _ in dd]), st.median([100 * x / b for x, b in dd]), sum(1 for x, _ in dd if x < 0)
        out.append(f"| {arm_b} | " + " | ".join(cells) + f" | {md:+.3f} | {mp:+.2f}% | {lower} of {len(dd)} |")
        out.append("")
        if name == "steady gap":
            n = len(dd)
            if n == 6 and lower == 6 and mp <= -3.0:
                verdict = "PASS"
            elif lower < 5 or abs(mp) <= 1.0:
                verdict = "KILL"
            else:
                verdict = "UNDECIDED"
            out.append(f"**Verdict by the fixed rule (steady gap, n = {n} passes): {verdict}** (lower in {lower} of {n}; median {mp:+.2f}%)")
            out.append("")
    keys = [("pc", "prove call"), ("com", "commit"), ("forks", "forks"), ("join", "join"), ("hold", "prover hold (left - entered)"),
            ("wait", "prover wait (entered - sealing side done)"), ("tw", "prover-turn wait inside the call"), ("seal", "sealing pass"), ("w", "receipt write")]
    rmax = max(nreq.values())
    for key, name in keys:
        out.append(f"| {name} by request (s, median over passes) | " + " | ".join(f"q{q}" for q in range(rmax)) + " | median q1-q6 |")
        out.append("|---|" + "---|" * (rmax + 1))
        for a in arms:
            cells = []
            for q in range(rmax):
                v = [reqs[(a, p, q)][key] for p in passes if (a, p, q) in reqs]
                cells.append(f"{st.median(v):.3f}" if v else "-")
            mid = [reqs[(a, p, q)][key] for p in passes for q in range(1, min(7, nreq[a])) if (a, p, q) in reqs]
            out.append(f"| {a} | " + " | ".join(cells) + f" | {st.median(mid):.3f} |")
        out.append("")
    out.append("| footprint per arm (GiB, over passes) | start median | peak median | peak max | end median | CPU user+sys per pass median (s) |")
    out.append("|---|---|---|---|---|---|")
    for a in arms:
        s = [v for (x, _), v in streams.items() if x == a]
        f = lambda k: [float(v[k]) for v in s]
        cpu = [float(v["u"]) + float(v["s"]) for v in s]
        out.append(f"| {a} | {st.median(f('f0')):.1f} | {st.median(f('f1')):.1f} | {max(f('f1')):.1f} | {st.median(f('f2')):.1f} | {st.median(cpu):.1f} |")
    out.append("")
    textout = "\n".join(out)
    print(textout)
    (HERE / f"A35_TERMS_{label}.md").write_text(textout + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
