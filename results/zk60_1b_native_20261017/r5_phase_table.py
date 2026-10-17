#!/usr/bin/env python3
"""NATIVE LANE round 5: aggregate the per-block phase tables (HL_PB_TIMING=1,
round-5 format with counted work, ns/unit, bytes and GB/s) of one stack run
over all its blocks. usage: r5_phase_table.py <prove.log> [...]"""
import re, sys, json, collections
for path in sys.argv[1:]:
    ph = collections.OrderedDict()
    halves = collections.OrderedDict()
    walls = []
    proved = None
    for line in open(path, errors="replace"):
        if line.startswith("PB-TIMING prove |"):
            parts = [p.strip() for p in line.split("|")]
            name, half = parts[1], parts[2]
            if name == "phase":
                continue
            if name.startswith("WALL CLOCK"):
                walls.append(float(parts[3]))
                continue
            if name.startswith("SUM OF") or name.startswith("unaccounted"):
                continue
            secs = float(parts[3])
            size_unit = parts[5]
            nbytes = int(parts[9]) if len(parts) > 10 and parts[9].isdigit() else 0
            size = int(size_unit.split()[0]) if size_unit.split() and size_unit.split()[0].isdigit() else 0
            unit = " ".join(size_unit.split()[1:])
            e = ph.setdefault(name, dict(half=half, secs=0.0, size=0, unit=unit, bytes=0, n=0))
            e["secs"] += secs; e["size"] += size; e["bytes"] += nbytes; e["n"] += 1
            halves[half] = halves.get(half, 0.0) + secs
        elif line.startswith('{"event":"proved"'):
            proved = json.loads(line)
    wall = sum(walls)
    print(f"## {path}\n")
    p = proved or {}
    print(f"{len(walls)} block phase tables, sum of block walls {wall:.1f} s; prove_run {p.get('prove_run_seconds')} s (witness {p.get('of_which_witness_seconds')} s, block loads {p.get('of_which_block_load_seconds')} s); gpu: {p.get('gpu')}\n")
    print("| half | seconds | % |\n|---|---|---|")
    for h, s in sorted(halves.items(), key=lambda x: -x[1]):
        print(f"| {h} | {s:.2f} | {100 * s / wall:.1f}% |")
    print("\n| phase (summed over blocks) | seconds | % | counted work | ns per unit | bytes | GB/s |\n|---|---|---|---|---|---|---|")
    for n, e in sorted(ph.items(), key=lambda x: -x[1]["secs"])[:24]:
        ns = 1e9 * e["secs"] / e["size"] if e["size"] else 0
        gbs = e["bytes"] / e["secs"] / 1e9 if e["bytes"] and e["secs"] else 0
        print(f"| {n} | {e['secs']:.2f} | {100 * e['secs'] / wall:.1f}% | {e['size']:,} {e['unit']} | {ns:.3f} | {e['bytes']:,} | {gbs:.3f} |")
    print()
