#!/usr/bin/env python3
"""Per-pass GPU sums from `HL_A27_GPU_TRACE` files: this run's four arms and, with the same code, the two retained
arm A traces of 2026-11-17 (`results/zk60_slot18_14_breakdown_20261117/`). Writes `summary.json` and prints a table.

By the Claude co-coordinator, 2026-11-20. The record format and the category rule follow
`results/zk60_slot18_14_breakdown_20261117/analyze_slot_breakdown.py` (`parse_trace_passes`,
`summarize_batched_arm`); the one difference is that a pass starts at every commit whose row count equals the
trace's FIRST commit's, instead of at two fixed row counts.
"""
import glob
import gzip
import json
import pathlib
import re
import statistics
from collections import defaultdict

REPO = pathlib.Path("/Users/victorrielly/IntelligenceRegulation")
OUT = REPO / "results/zk60_w16r2_shield_block_20261120"
RAW = OUT / "raw"
EXT = pathlib.Path("/Users/victorrielly/zk60-artifacts/w16r2_shield_block_20261120")
OLD = pathlib.Path("/Users/victorrielly/zk60-artifacts/slot18_14_traces_20261117")
SLOT_TAGS = ("batch", "round-batch", "round", "fold", "tables")
M4 = re.compile(r"M4-TRAINED (\S+) cpu ([\d.]+) s metal-(\w+) ([\d.]+) s \(prove core cpu ([\d.]+) s metal ([\d.]+) s;"
                r".*?digest cpu ([0-9a-f]+) metal ([0-9a-f]+)")


def records(gz):
    out = []
    with gzip.open(gz, "rt") as f:
        lines = [ln.rstrip("\n") for ln in f if ln.strip()]
    for ln in lines[1:]:
        p = ln.split("\t")
        if len(p) < 9:
            continue
        tag, detail = p[0], p[1]
        committed, gs, ge, done = float(p[5]), float(p[6]), float(p[7]), float(p[8])
        ms = (ge - gs) * 1000.0 if (ge > gs and gs > 0.0) else (done - committed) * 1000.0
        out.append((tag, detail, ms))
    return out


def rows_of(detail):
    m = re.match(r"rows=(\d+) ", detail)
    return int(m.group(1)) if m else None


def passes(recs):
    commits = [(i, rows_of(d)) for i, (t, d, _) in enumerate(recs) if t == "commit"]
    a_rows = commits[0][1]
    starts = [i for i, r in commits if r == a_rows]
    out = []
    for k, s in enumerate(starts):
        e = starts[k + 1] if k + 1 < len(starts) else len(recs)
        out.append([r for r in recs[s:e] if r[0] != "wprod"])
    other_rows = sorted({r for _, r in commits if r != a_rows})
    return a_rows, other_rows, out


def summarize(gz):
    a_rows, other_rows, ps = passes(records(gz))
    warm = ps[1:] if len(ps) > 1 else ps
    cats, slots = defaultdict(list), defaultdict(list)
    for p in warm:
        c, s = defaultdict(float), defaultdict(float)
        for tag, det, ms in p:
            c["total"] += ms
            if tag == "commit":
                c["commit_A" if rows_of(det) == a_rows else "commit_H"] += ms
            elif tag in SLOT_TAGS:
                c["slots"] += ms
                if " | " in det:
                    s[det.split(" | ", 1)[0]] += ms
            else:
                c["other_" + tag] += ms
        c["block_gpu"] = c["total"] - c.get("other_diag", 0.0)
        c["commit_AH"] = c["commit_A"] + c["commit_H"]
        for k, v in c.items():
            cats[k].append(v)
        for k, v in s.items():
            slots[k].append(v)
    med = {k: round(statistics.median(v), 3) for k, v in sorted(cats.items())}
    per_pass = {k: [round(x, 3) for x in cats[k]] for k in ("block_gpu", "commit_AH", "slots")}
    sl = sorted(({"slot": k, "median_ms": round(statistics.median(v), 3)} for k, v in slots.items()),
                key=lambda x: -x["median_ms"])
    return {"trace": str(gz), "a_commit_rows": a_rows, "other_commit_rows": other_rows, "passes_found": len(ps),
            "warm_passes": len(warm), "median_ms": med, "per_pass_ms": per_pass, "slots": sl}


def m4_rows(label):
    p = RAW / (label + ".guard.txt")
    rows = []
    if p.exists():
        for ln in p.read_text().splitlines():
            m = M4.search(ln)
            if m:
                rows.append({"profile": m.group(1), "kind": m.group(3), "cpu_s": float(m.group(2)), "metal_s": float(m.group(4)),
                             "metal_core_s": float(m.group(6)), "digests_equal": m.group(7) == m.group(8), "digest": m.group(8)})
    return rows


def short(label):
    m = re.match(r"slot (\d+) \((.*?)\) at \S+: (\d+) tables \((\d+) base\), (\d+) nodes", label)
    return ("slot %s: %s tables (%s base), %s nodes" % (m.group(1), m.group(3), m.group(4), m.group(5))) if m else label[:60]


def main():
    arms = {}
    for label in ("w16r2_shield_a1", "w16r2_8b_ctl", "r13_shield_ctl", "w16r2_shield_a2"):
        g = sorted(glob.glob(str(EXT / (label + ".*.tsv.gz"))))
        assert len(g) == 1, (label, g)
        a = summarize(g[0])
        m = m4_rows(label)
        assert m and all(r["digests_equal"] for r in m), label
        warm = [r for r in m if r["kind"] == "warm"]
        a["m4"] = {"profile": m[0]["profile"], "digest": m[0]["digest"], "cpu_s": m[0]["cpu_s"],
                   "metal_warm_wall_median_s": round(statistics.median(r["metal_s"] for r in warm), 4) if warm else None,
                   "metal_warm_core_median_s": round(statistics.median(r["metal_core_s"] for r in warm), 4) if warm else None}
        arms[label] = a
    for label in ("w16r2_8b_armA_prod_batched", "r13_shield_armA_prod_batched"):
        g = sorted(glob.glob(str(OLD / (label + ".*.tsv.gz"))))
        assert len(g) == 1, (label, g)
        arms["20261117_" + label] = summarize(g[0])
    (OUT / "summary.json").write_text(json.dumps(arms, indent=2) + "\n")
    print("%-40s %6s %5s %9s %9s %9s %9s %9s" % ("arm", "A rows", "warm", "block GPU", "commit A", "commit H", "A + H", "slots"))
    for k, a in arms.items():
        m = a["median_ms"]
        print("%-40s %6d %5d %9.2f %9.2f %9.2f %9.2f %9.2f" % (k, a["a_commit_rows"], a["warm_passes"], m["block_gpu"],
                                                               m["commit_A"], m["commit_H"], m["commit_AH"], m["slots"]))
    for k, a in arms.items():
        print("\n" + k, "| other commit rows", a["other_commit_rows"], "| per-pass block GPU", a["per_pass_ms"]["block_gpu"],
              "| categories", {x: y for x, y in a["median_ms"].items() if x.startswith("other_")}, "| m4", a.get("m4", ""))
        for s in a["slots"][:6]:
            print("   %8.3f ms  %s" % (s["median_ms"], short(s["slot"])))


if __name__ == "__main__":
    main()
