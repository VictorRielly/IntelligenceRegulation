#!/usr/bin/env python3
"""Steady gap per pass and per arm from the A22-AB STREAM lines of raw/<label>.log. Standard library only.

usage: python3 -B analyze_stream.py        prints the tables and writes summary.json

Steady gap of a pass with R requests: (completion[R-2] - completion[1]) / (R-3), the rule of
results/zk60_a35_replication_20261120/README.md (the first two and the last request are left out). Checked against
that directory's log: this script gives its table (3.814 and 3.560 s medians at two lanes).
"""
import json
import re
import statistics
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
LINE = re.compile(r"A22-AB STREAM (\S+) L(\d+) N(\d+) \[(.+?)\] pass (\d+): (\d+) requests in ([\d.]+) s .*?"
                  r"steady ([\d.]+) tok/s; amortized ([\d.]+) tok/s; completions ([\d., ]+);")
TOKENS = 128


def parse(path):
    arms = {}
    meta = None
    for l in Path(path).read_text(errors="replace").splitlines():
        m = LINE.search(l)
        if not m:
            continue
        prof, layers, workers, arm, p, r, wall, steady, amort, comp = m.groups()
        c = [float(x) for x in comp.split(",")]
        r = int(r)
        assert len(c) == r, (arm, p, len(c), r)
        gap = (c[r - 2] - c[1]) / (r - 3)
        arms.setdefault(arm, {})[int(p)] = {"gap": gap, "steady_tok_s": float(steady), "wall": float(wall)}
        meta = (prof, int(layers), int(workers))
    return meta, arms


def table(label, path):
    meta, arms = parse(path)
    if not arms:
        print(f"{label}: no stream lines in {path}")
        return None
    prof, layers, workers = meta
    res = {"profile": prof, "layers": layers, "workers": workers, "arms": {}}
    print(f"== {label}: {prof}, {layers} layers, {workers} fork workers")
    for arm, ps in arms.items():
        gaps = [ps[k]["gap"] for k in sorted(ps)]
        med = statistics.median(gaps)
        res["arms"][arm] = {"gaps_s": [round(g, 4) for g in gaps], "median_gap_s": round(med, 4),
                            "ms_per_block": round(med / layers * 1e3, 2), "tok_s_at_median_gap": round(TOKENS / med, 2),
                            "test_steady_tok_s": [ps[k]["steady_tok_s"] for k in sorted(ps)]}
        print("  %-22s gaps %s | median %.3f s | %.1f ms per block | %.2f tok/s" % (
            arm, " ".join("%.3f" % g for g in gaps), med, med / layers * 1e3, TOKENS / med))
    names = list(arms)
    off = [a for a in names if "+ba1" not in a]
    for a in off:
        on = a + "+ba1"
        if on in arms:
            ks = sorted(set(arms[a]) & set(arms[on]))
            d = [arms[on][k]["gap"] - arms[a][k]["gap"] for k in ks]
            base = statistics.median(arms[a][k]["gap"] for k in ks)
            md = statistics.median(d)
            res["arms"][on]["pair_minus_off_s"] = [round(x, 4) for x in d]
            res["arms"][on]["pair_median_s"] = round(md, 4)
            res["arms"][on]["pair_median_pct"] = round(100 * md / base, 2)
            res["arms"][on]["lower_in"] = "%d of %d" % (sum(1 for x in d if x < 0), len(d))
            print("  pair %s minus %s: %s | median %.3f s (%.2f%%) | lower in %d of %d" % (
                on, a, " ".join("%+.3f" % x for x in d), md, 100 * md / base, sum(1 for x in d if x < 0), len(d)))
    return res


def main():
    out = {}
    if len(sys.argv) > 1:
        for p in sys.argv[1:]:
            table(p, p)
        return
    for label in ("shield26", "ctl8b32"):
        p = HERE / "raw" / f"{label}.log"
        if p.exists():
            out[label] = table(label, p)
        else:
            print(f"{label}: raw/{label}.log is not there")
    (HERE / "summary.json").write_text(json.dumps(out, indent=1) + "\n")


main()
