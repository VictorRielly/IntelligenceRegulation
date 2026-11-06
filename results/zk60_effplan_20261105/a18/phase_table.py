#!/usr/bin/env python3
"""A18: the per-block phase rows of several arms, side by side (the mean over each arm's passes).

usage: phase_table.py <d55.log> <arm> [<arm> ...]

Reads the harness's A11 phase lines
  `D55-AB A11 PHASE N6 [<arm>] | <label> | <s> s summed over <n> forks | <ms> ms per block | <pct>%`
(one block of them per proof-only call of an arm with `phases`) and prints, per label, each arm's mean ms per block
and its change against the first arm.
"""
import collections
import re
import sys

path, arms = sys.argv[1], sys.argv[2:]
row = re.compile(r"^D55-AB A11 PHASE N6 \[([^\]]*)\] \| (.+?)\s+\|\s+[\d.]+ s summed over \d+ forks \|\s+([\d.]+) ms per block")
vals = collections.defaultdict(lambda: collections.defaultdict(list))
order = []
with open(path, errors="replace") as f:
    for line in f:
        m = row.match(line)
        if not m:
            continue
        arm, label, ms = m.group(1), m.group(2).strip(), float(m.group(3))
        if label not in order:
            order.append(label)
        vals[label][arm].append(ms)
mean = lambda v: sum(v) / len(v) if v else float("nan")
print(f"# A18 phase clock, ms per block (mean over passes), N = 6 ({path})")
print()
print("| phase | " + " | ".join(arms) + " |")
print("|---|" + "---:|" * len(arms))
for label in order:
    base = mean(vals[label].get(arms[0], []))
    cells = []
    for i, a in enumerate(arms):
        v = mean(vals[label].get(a, []))
        cells.append(f"{v:.2f}" if i == 0 else f"{v:.2f} ({v - base:+.2f})")
    print(f"| {label[:60]} | " + " | ".join(cells) + " |")
