#!/usr/bin/env python3
"""A33 G5: parse raw/<arm>_<i><A|B>.log into per-run and pooled tables (stdout, and AB_TABLES.md).

serve1: per warm pass, request 0's `sealing pass` seconds and `result` seconds (the request wall).
serve4: per warm pass, the stream's `steady` tok/s, the cadence (result of request 3 minus request 0, over 3), and
        request 0's sealing pass; also the sealing pass of requests 1..3 (overlapped with a proof).
Medians, quartiles and min/max are over the warm passes (the cold request is not in them).
"""
import json
import re
import statistics as st
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
RAW = HERE / "raw"
REQ = re.compile(r"\[(serve\d)\] pass (\d+) request (\d+): .*?\(sealing pass ([0-9.]+) s\).*?result ([0-9.]+);")
STREAM = re.compile(r"\[(serve\d)\] pass (\d+): (\d+) requests in ([0-9.]+) s .*?steady ([0-9.]+|NaN) tok/s; amortized ([0-9.]+) tok/s")


def q(v, p):
    s = sorted(v)
    pos = p * (len(s) - 1)
    lo = int(pos)
    hi = min(lo + 1, len(s) - 1)
    return s[lo] * (1 - (pos - lo)) + s[hi] * (pos - lo)


def summ(v):
    return {"n": len(v), "median": round(st.median(v), 4), "p25": round(q(v, .25), 4), "p75": round(q(v, .75), 4), "min": round(min(v), 4), "max": round(max(v), 4), "mean": round(st.mean(v), 4)}


def parse(path: Path, arm: str):
    txt = path.read_text()
    reqs = {}
    for m in REQ.finditer(txt):
        reqs[(int(m.group(2)), int(m.group(3)))] = (float(m.group(4)), float(m.group(5)))
    streams = {int(m.group(2)): (m.group(5), float(m.group(6))) for m in STREAM.finditer(txt)}
    passes = sorted({p for p, _ in reqs})
    rows = []
    for p in passes:
        r0 = reqs[(p, 0)]
        row = {"pass": p, "seal0": r0[0], "wall0": r0[1]}
        if arm == "serve4":
            last = max(k for (pp, k) in reqs if pp == p)
            row["cadence"] = (reqs[(p, last)][1] - r0[1]) / last
            row["seal_ov"] = st.mean([reqs[(p, k)][0] for k in range(1, last + 1)])
            row["steady_toks"] = float(streams[p][0]) if streams[p][0] != "NaN" else float("nan")
        rows.append(row)
    ok = "test result: ok." in txt
    verified = len(re.findall(r"all \d+ receipts verified from their run directories", txt))
    return rows, ok, verified


def main():
    arm = sys.argv[1]
    pre = sys.argv[2] if len(sys.argv) > 2 else ""  # "m_": the merged tree's runs
    files = sorted(RAW.glob(f"{pre}{arm}_[0-9]*[AB].log"), key=lambda p: int(re.match(rf"{pre}{arm}_(\d+)", p.name).group(1)))
    out = []
    per = {"A": [], "B": []}
    keys = ["seal0", "wall0"] if arm == "serve1" else ["cadence", "steady_toks", "seal0", "seal_ov", "wall0"]
    pooled = {"A": {k: [] for k in keys}, "B": {k: [] for k in keys}}
    out.append(f"### {arm}: per run (warm passes 0-5 each; medians)\n")
    out.append("| run | binary | " + " | ".join(f"{k} median [min-max]" for k in keys) + " | test | receipts-verified lines |")
    out.append("|---|---|" + "---|" * (len(keys) + 2))
    for f in files:
        who = f.name[-5]
        rows, ok, ver = parse(f, arm)
        for k in keys:
            pooled[who][k] += [r[k] for r in rows]
        cells = []
        for k in keys:
            v = [r[k] for r in rows]
            cells.append(f"{st.median(v):.3f} [{min(v):.3f}-{max(v):.3f}]")
        out.append(f"| {f.stem} | {'unpatched' if who == 'A' else 'patched'} | " + " | ".join(cells) + f" | {'ok' if ok else 'FAIL'} | {ver} (n={len(rows)}) |")
    out.append("")
    out.append(f"### {arm}: pooled over the runs (n warm passes per binary)\n")
    out.append("| metric | n | unpatched median [p25-p75] | patched median [p25-p75] | patched minus unpatched (medians) |")
    out.append("|---|---|---|---|---|")
    res = {}
    for k in keys:
        a, b = summ(pooled["A"][k]), summ(pooled["B"][k])
        d = b["median"] - a["median"]
        res[k] = {"A": a, "B": b, "delta_median": round(d, 4)}
        out.append(f"| {k} | {a['n']}/{b['n']} | {a['median']:.3f} [{a['p25']:.3f}-{a['p75']:.3f}] | {b['median']:.3f} [{b['p25']:.3f}-{b['p75']:.3f}] | {d:+.3f} |")
    # run-to-run spread of the per-run medians (pair differences in order)
    out.append("")
    byrun = {}
    for f in files:
        rows, _, _ = parse(f, arm)
        byrun[f.stem] = rows
    out.append(f"per-run-median pairs, A-run median minus the next B-run median ({keys[0]}):")
    names = [f.stem for f in files]
    for i in range(0, len(names) - 1, 2):
        a = st.median([r[keys[0]] for r in byrun[names[i]]])
        b = st.median([r[keys[0]] for r in byrun[names[i + 1]]])
        out.append(f"- {names[i]} -> {names[i+1]}: {a:.3f} -> {b:.3f} ({b - a:+.3f})")
    text = "\n".join(out)
    print(text)
    (HERE / f"AB_TABLES_{pre}{arm}.md").write_text(text + "\n")
    (HERE / f"AB_METRICS_{pre}{arm}.json").write_text(json.dumps(res, indent=1))


if __name__ == "__main__":
    main()
