#!/usr/bin/env python3
"""A16: the sealing pass ALONE (`HL_A16_SEAL_AB`, the harness's `D55-AB A16 SEALONLY` lines; A15's alone_table.py): per arm, the mean
over passes of the wall, user and system CPU, cores busy, involuntary context switches and minor faults, and the
wall's paired change against a base arm by arm order (the whole arm order is reversed in odd passes, so the base ran
first or last; the order-bias column is the mean of the two orders' means).

usage: alone_table.py <d55.log> [--base sp0]
"""
import collections
import re
import sys

a = sys.argv[1:]
path = a[0]
base = a[a.index("--base") + 1] if "--base" in a else "spauto+a16old"
pat = re.compile(
    r"^D55-AB A16 SEALONLY \S+ L\d+ \[([^\]]+)\] pass (\d+): wall ([\d.]+) s in (.*?); user ([\d.]+) s \+ sys ([\d.]+) s = ([\d.]+) cores; "
    r"csw voluntary (\d+), involuntary (\d+); minor faults (\d+)"
)
vals = collections.defaultdict(dict)  # arm -> pass -> (wall, user, sys, cores, nvcsw, nivcsw, flt)
where = {}
order = []
with open(path, errors="replace") as f:
    for line in f:
        m = pat.match(line)
        if not m:
            continue
        arm = m.group(1)
        if arm not in where:
            order.append(arm)
        where[arm] = m.group(4)
        vals[arm][int(m.group(2))] = tuple(float(m.group(i)) for i in (3, 5, 6, 7, 8, 9, 10))
print(f"# A16 the sealing pass alone (32 serial witness builds, W16R2 8B T128): means over passes ({path})")
print()
print("| arm | where | passes | wall s | user CPU s | sys CPU s | cores busy | csw voluntary | csw involuntary | minor faults | wall vs base, base first / last / order bias out |")
print("|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---|")
for arm in order:
    v = vals[arm]
    n = len(v)
    mean = [sum(x[i] for x in v.values()) / n for i in range(7)]
    pair = "—"
    if arm != base and base in vals:
        by = {True: [], False: []}
        for p, x in v.items():
            if p in vals[base]:
                by[p % 2 == 0].append(x[0] / vals[base][p][0] - 1.0)
        f = lambda xs: f"{100 * sum(xs) / len(xs):+.1f}%" if xs else "—"
        solved = f"**{100 * (sum(by[True]) / len(by[True]) + sum(by[False]) / len(by[False])) / 2:+.1f}%**" if by[True] and by[False] else "—"
        pair = f"{f(by[True])} / {f(by[False])} / {solved}"
    print(f"| {arm} | {where[arm]} | {n} | {mean[0]:.3f} | {mean[1]:.2f} | {mean[2]:.2f} | {mean[3]:.1f} | {mean[4]:,.0f} | {mean[5]:,.0f} | {mean[6]:,.0f} | {pair} |")
