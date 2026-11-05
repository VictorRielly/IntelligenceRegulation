#!/usr/bin/env python3
"""A12: per proof-only fork call of the in-process A/B (`HL_D55_GPU_AB`), the wall, the forks
phase, the fork workers' table-build time per block (`D55-AB A12 TABLES`), and, with
`HL_D55_TIMELINE=1`, the GPU busy time over the forks phase and the `tables` command buffers'
GPU time. Then the means per (arm, N).

usage: summarize.py <d55.log>

A call's lines come in this order: `A7 CPU`, `A11 USAGE`, `A12 TABLES`, `A7 TIMELINE` (the whole
call, then the forks phase), then the `GPU-AB ... pass <p>` line that names the arm and pass.
"""
import collections
import re
import sys

path = sys.argv[1]
tables = re.compile(r"^D55-AB A12 TABLES \S+ L\d+ forks N(\d+) \[([^\]]*)\]: table builds ([\d.]+) ms per block")
slot = re.compile(r"s(\d\d) ([\d.]+) ms \((\d+)/(\d+) dev\)")
forks_tl = re.compile(r"^D55-AB A7 TIMELINE \S+ L\d+ forks N(\d+) .*the forks phase, ([\d.]+) s")
busy = re.compile(r"^  window ([\d.]+) s: (\d+) command buffers; GPU busy \(>= 1 executing\) ([\d.]+) s")
tag = re.compile(r"^  tag (\S+)\s+(\d+) cbs: GPU ([\d.]+) s .*commit -> GPU start ([\d.]+) s")
proof = re.compile(r"^D55-AB GPU-AB \S+ L\d+ T\d+ forks N(\d+) \[([^\]]+)\] pass (\d+): wall ([\d.]+) s.*forks ([\d.]+) s, join")

rows = []
cur = {}
in_forks_window = False
with open(path, errors="replace") as f:
    for line in f:
        m = tables.match(line)
        if m:
            cur = {"tables_ms": float(m.group(3)), "slots": {s: (float(ms), int(d), int(b)) for s, ms, d, b in slot.findall(line)}}
            in_forks_window = False
            continue
        m = forks_tl.match(line)
        if m:
            in_forks_window = True
            continue
        if in_forks_window:
            m = busy.match(line)
            if m:
                cur["busy_s"] = float(m.group(3))
                cur["cbs"] = int(m.group(2))
                continue
            m = tag.match(line)
            if m:
                cur.setdefault("tags", {})[m.group(1)] = (int(m.group(2)), float(m.group(3)), float(m.group(4)))
                continue
            if not line.startswith("  "):
                in_forks_window = False
        m = proof.match(line)
        if m:
            r = dict(cur)
            r.update({"n": int(m.group(1)), "arm": m.group(2), "pass": int(m.group(3)), "wall": float(m.group(4)), "forks": float(m.group(5))})
            rows.append(r)
            cur = {}

print(f"# A12 summary of {path}")
print()
print("| arm | N | pass | wall s | forks s | table builds ms/block | GPU busy in forks s | tables cbs: GPU s, commit->start s | slot 18 / 14 / 17 ms per block |")
print("|---|---:|---:|---:|---:|---:|---:|---|---|")
for r in rows:
    t = r.get("tags", {}).get("tables")
    tcell = f"{t[0]}: {t[1]:.3f}, {t[2]:.3f}" if t else "—"
    sl = r.get("slots", {})
    scell = " / ".join(f"{sl[s][0]:.1f}" if s in sl else "—" for s in ["18", "14", "17"])
    b = r.get("busy_s")
    print(f"| {r['arm']} | {r['n']} | {r['pass']} | {r['wall']:.3f} | {r['forks']:.3f} | {r.get('tables_ms', float('nan')):.2f} | {'—' if b is None else f'{b:.3f}'} | {tcell} | {scell} |")
print()
agg = collections.defaultdict(list)
for r in rows:
    agg[(r["arm"], r["n"])].append(r)
print("| arm | N | calls | mean wall s | mean forks s | mean table builds ms/block | mean GPU busy in forks s |")
print("|---|---:|---:|---:|---:|---:|---:|")
for (arm, n), v in sorted(agg.items(), key=lambda kv: (kv[0][1], kv[0][0])):
    mean = lambda k: sum(x[k] for x in v if k in x) / max(1, sum(1 for x in v if k in x))
    bz = [x["busy_s"] for x in v if "busy_s" in x]
    print(f"| {arm} | {n} | {len(v)} | {mean('wall'):.3f} | {mean('forks'):.3f} | {mean('tables_ms'):.2f} | {(sum(bz) / len(bz)) if bz else float('nan'):.3f} |")
