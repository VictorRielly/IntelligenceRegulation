#!/usr/bin/env python3
"""Parse and verify Set 1 (two-binary A/B/C/C/B/A) and Set 2 (6-pass B1 hw0 vs hw1+ad0) plus guard overlap."""
import json
import re
import statistics
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
RAW = HERE / "raw"
HIST = Path("/Users/victorrielly/IntelligenceRegulation/results/zk60_resource_guard/history.jsonl")

STREAM_RE = re.compile(
    r"A22-AB STREAM \S+ L\d+ N\d+ \[([^\]]+)\] pass (\d+): (\d+) requests in ([0-9.]+) s \(([^)]*)\).*?completions ([0-9., ]+);"
)
CPU_RE = re.compile(r"user\s+([0-9.]+)\s+s\s+\+\s+sys\s+([0-9.]+)\s+s")
FOOT_RE = re.compile(r"footprint start [0-9.]+ GiB, peak ([0-9.]+) GiB, end [0-9.]+ GiB")


def parse_stream_lines(text: str):
    rows = []
    for line in text.splitlines():
        m = STREAM_RE.search(line)
        if not m:
            continue
        arm, ps, r, wall, flags, comps = m.group(1), int(m.group(2)), int(m.group(3)), float(m.group(4)), m.group(5), m.group(6)
        c = [float(x) for x in comps.split(",")]
        assert len(c) == r, (arm, ps, len(c), r)
        gap = (c[r - 2] - c[1]) / (r - 3)
        rate = 128.0 / gap
        mc = CPU_RE.search(line)
        cpu_u, cpu_s = (float(mc.group(1)), float(mc.group(2))) if mc else (None, None)
        mf = FOOT_RE.search(line)
        foot = float(mf.group(1)) if mf else None
        rows.append({
            "arm": arm, "pass": ps, "r": r, "wall": wall, "flags": flags,
            "c": c, "gap": gap, "rate": rate,
            "cpu_u": cpu_u, "cpu_s": cpu_s, "cpu_tot": (cpu_u + cpu_s) if cpu_u is not None else None,
            "foot": foot,
        })
    return rows


def check_overlap(guard_json_path: Path):
    if not guard_json_path.exists():
        return "missing"
    gj = json.loads(guard_json_path.read_text())
    rid = gj["run_id"]
    t_end = gj["ts_end"]
    # compute start approx from wall
    from datetime import datetime, timedelta
    dt_end = datetime.fromisoformat(t_end.replace("Z", "+00:00"))
    dt_start = dt_end - timedelta(seconds=float(gj["guard_wall_s"]))
    overlaps = []
    for line in HIST.read_text().splitlines():
        if not line.strip():
            continue
        rec = json.loads(line)
        if rec.get("run_id") == rid:
            continue
        re_end = datetime.fromisoformat(rec["ts_end"].replace("Z", "+00:00"))
        re_start = re_end - timedelta(seconds=float(rec.get("guard_wall_s") or 0.0))
        if re_start < dt_end and re_end > dt_start:
            overlaps.append((rec.get("run_id"), rec.get("label"), rec.get("ts_end")))
    return overlaps


def summarize_set1():
    meta_p = RAW / "set1_meta.json"
    if not meta_p.exists():
        print("SET1: not present")
        return
    meta = json.loads(meta_p.read_text())
    print("=== SET 1 (two-binary fresh-process: lead-in A0, then A1 B1 C1 C2 B2 A2) ===")
    by_leg = {}
    for m in meta:
        txt = Path(m["log"]).read_text(errors="replace")
        rows = parse_stream_lines(txt)
        ver = sum(1 for l in txt.splitlines() if "verified" in l.lower() and "A22-AB" in l)
        passed = "test result: ok. 1 passed; 0 failed" in txt
        assert len(rows) == 1, (m["leg"], len(rows))
        r = rows[0]
        by_leg[m["leg"]] = r
        print(
            f"  {m['leg']:10s} exit={m['exit']} pass={passed} gap={r['gap']:.3f}s "
            f"rate={r['rate']:.2f} tok/s cpu={r['cpu_tot']}s foot={r['foot']}GiB flags=[{r['flags']}]"
        )
    a1, b1, c1 = by_leg["A1"], by_leg["B1"], by_leg["C1"]
    c2, b2, a2 = by_leg["C2"], by_leg["B2"], by_leg["A2"]
    c_over_a_1 = 100.0 * (1.0 - c1["gap"] / a1["gap"])
    c_over_a_2 = 100.0 * (1.0 - c2["gap"] / a2["gap"])
    c_rate_1 = 100.0 * (c1["rate"] / a1["rate"] - 1.0)
    c_rate_2 = 100.0 * (c2["rate"] / a2["rate"] - 1.0)
    mean_a_rate = 0.5 * (a1["rate"] + a2["rate"])
    mean_b_rate = 0.5 * (b1["rate"] + b2["rate"])
    mean_c_rate = 0.5 * (c1["rate"] + c2["rate"])
    mean_a_gap = 0.5 * (a1["gap"] + a2["gap"])
    mean_b_gap = 0.5 * (b1["gap"] + b2["gap"])
    mean_c_gap = 0.5 * (c1["gap"] + c2["gap"])
    r_b_vs_a = 100.0 * (mean_b_rate / mean_a_rate - 1.0)
    r_c_vs_a = 100.0 * (mean_c_rate / mean_a_rate - 1.0)
    print(f"  Mean gaps : A={mean_a_gap:.3f}s ({mean_a_rate:.2f} tok/s), B={mean_b_gap:.3f}s ({mean_b_rate:.2f} tok/s), C={mean_c_gap:.3f}s ({mean_c_rate:.2f} tok/s)")
    print(f"  C vs A gap reduction: pair1={c_over_a_1:+.2f}% (rate {c_rate_1:+.2f}%), pair2={c_over_a_2:+.2f}% (rate {c_rate_2:+.2f}%), mean rate {r_c_vs_a:+.2f}%")
    print(f"  B vs A default-path : pair1={100.0*(b1['rate']/a1['rate']-1):+.2f}%, pair2={100.0*(b2['rate']/a2['rate']-1):+.2f}%, r(mean_B/mean_A - 1)={r_b_vs_a:+.2f}%")
    print(f"  Guard overlap check : {check_overlap(RAW / 'set1.guard.json')}")


def summarize_set2():
    log_p = RAW / "set2.log"
    if not log_p.exists():
        print("SET2: not present")
        return
    txt = log_p.read_text(errors="replace")
    rows = parse_stream_lines(txt)
    print("\n=== SET 2 (single-process 6-pass alternating B1: hw0 vs hw1+ad0) ===")
    by_arm = {}
    for r in rows:
        by_arm.setdefault(r["arm"], {})[r["pass"]] = r
    for arm, d in by_arm.items():
        ps = sorted(d)
        gs = [d[p]["gap"] for p in ps]
        cs = [d[p]["cpu_tot"] for p in ps]
        med_g = statistics.median(gs)
        med_c = statistics.median(cs) if all(x is not None for x in cs) else None
        print(f"  {arm}: gaps={' '.join(f'{x:.3f}' for x in gs)} | med={med_g:.3f}s ({128.0/med_g:.2f} tok/s) | cpu_med={med_c}")
    a_off = "serve8+lanes2+ba1+frs1+sf1+sc1+hf1+q0+hw0"
    a_on = "serve8+lanes2+ba1+frs1+sf1+sc1+hf1+q0+hw1+ad0"
    if a_off in by_arm and a_on in by_arm:
        ps = sorted(set(by_arm[a_off]) & set(by_arm[a_on]))
        dg = [by_arm[a_on][p]["gap"] - by_arm[a_off][p]["gap"] for p in ps]
        dc = [by_arm[a_on][p]["cpu_tot"] - by_arm[a_off][p]["cpu_tot"] for p in ps]
        med_off = statistics.median([by_arm[a_off][p]["gap"] for p in ps])
        med_off_c = statistics.median([by_arm[a_off][p]["cpu_tot"] for p in ps])
        med_dg = statistics.median(dg)
        med_dc = statistics.median(dc)
        low_g = sum(1 for x in dg if x < 0)
        low_c = sum(1 for x in dc if x < 0)
        print(f"  hw1+ad0 minus hw0 gap : per-pass={' '.join(f'{x:+.3f}' for x in dg)} | med={med_dg:+.3f}s ({100.0*med_dg/med_off:+.2f}%) | lower {low_g}/{len(ps)}")
        print(f"  hw1+ad0 minus hw0 CPU : per-pass={' '.join(f'{x:+.1f}' for x in dc)} | med={med_dc:+.2f}s ({100.0*med_dc/med_off_c:+.2f}%) | lower {low_c}/{len(ps)}")
    for line in txt.splitlines():
        if " SUMMARY " in line or line.startswith("test result"):
            print("  " + line)
    print(f"  Guard overlap check : {check_overlap(RAW / 'set2.guard.json')}")


if __name__ == "__main__":
    summarize_set1()
    summarize_set2()
