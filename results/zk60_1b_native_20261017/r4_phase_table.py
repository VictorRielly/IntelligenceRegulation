#!/usr/bin/env python3
"""NATIVE LANE round 4, R4-4: aggregate the per-block phase tables
(HL_PB_TIMING=1) of one stack run over all its blocks. usage:
r4_phase_table.py <prove.log> [<prove.log> ...]  (one column per log)"""
import re, sys, json, collections
cols = []
for path in sys.argv[1:]:
    phases = collections.OrderedDict()
    halves = collections.OrderedDict()
    steps = collections.OrderedDict()
    walls = []
    proved = None
    for line in open(path, errors="replace"):
        line = line.rstrip("\n")
        if line.startswith("PB-TIMING prove |"):
            parts = [p.strip() for p in line.split("|")]
            name, half, secs = parts[1], parts[2], parts[3]
            if name in ("phase",) or name.startswith("SUM OF") or name.startswith("WALL CLOCK") or name.startswith("unaccounted"):
                if name.startswith("WALL CLOCK"):
                    walls.append(float(secs))
                if name.startswith("unaccounted"):
                    phases["(unaccounted)"] = phases.get("(unaccounted)", 0.0) + float(secs)
                continue
            phases[name] = phases.get(name, 0.0) + float(secs)
            halves[half] = halves.get(half, 0.0) + float(secs)
        elif line.startswith("PB-SLOTSTEP"):
            m = re.match(r"PB-SLOTSTEP slot (\d+) \| (.*?)\s*\|\s*([\d.]+) s", line)
            if m:
                k = f"slot {m.group(1)} {m.group(2).strip()}"
                steps[k] = steps.get(k, 0.0) + float(m.group(3))
        elif line.startswith('{"event":"proved"'):
            proved = json.loads(line)
    cols.append(dict(path=path, phases=phases, halves=halves, steps=steps, wall=sum(walls), blocks=len(walls), proved=proved))
for c in cols:
    p = c["proved"] or {}
    print(f"## {c['path']}\n")
    print(f"{c['blocks']} block phase tables, sum of block walls {c['wall']:.1f} s; prove_run {p.get('prove_run_seconds')} s, witness {p.get('of_which_witness_seconds')} s, gpu: {p.get('gpu')}\n")
    print("| half | seconds | % of block walls |\n|---|---|---|")
    for h, s in sorted(c["halves"].items(), key=lambda x: -x[1]):
        print(f"| {h} | {s:.2f} | {100 * s / c['wall']:.1f}% |")
    print("\n| phase (summed over blocks) | seconds | % |\n|---|---|---|")
    for n, s in sorted(c["phases"].items(), key=lambda x: -x[1])[:25]:
        print(f"| {n} | {s:.2f} | {100 * s / c['wall']:.1f}% |")
    if c["steps"]:
        print("\n| slot step (summed over blocks) | seconds |\n|---|---|")
        for n, s in sorted(c["steps"].items(), key=lambda x: -x[1])[:20]:
            print(f"| {n} | {s:.2f} |")
    print()
