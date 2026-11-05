#!/usr/bin/env python3
"""A11: paired changes of an in-process A/B (`HL_D55_GPU_AB=<base>,<test>`), by arm order.

usage: pairs.py <d55.log> <base-label> <test-label> [--alternate] [--n 6]

Reads the per-call lines of the D55 harness:
  `D55-AB GPU-AB ... forks N<n> [<label>] pass <p>: wall <s> s ... forks <s> s ...` (proof only),
  `D55-AB A11 USAGE ... forks N<n> [<label>]: ... user <u> s + sys <s> s ... minor faults <f>`,
  `D55-AB GPU-AB PIPE ... forks N<n> [<label>] pass <p>: ... steady state <x> tok/s ...` (streams),
  `D55-AB GPU-AB ... forks N<n> [<label>] SEALED pass <p>: wall <s> s` (one request from its input).
For every pass holding both arms it forms test / base - 1 per metric, and says which arm ran first
(with `--alternate`, the base runs first in even passes and second in odd ones; without it, the
base always runs first). The order bias cancels in the mean of the two orders' means.
"""
import collections
import re
import sys

a = sys.argv[1:]
path, base, test = a[0], a[1], a[2]
alternate = "--alternate" in a
n_want = a[a.index("--n") + 1] if "--n" in a else "6"

proof = re.compile(r"^D55-AB GPU-AB \S+ L\d+ T\d+ forks N(\d+) \[([^\]]+)\] pass (\d+): wall ([\d.]+) s.*forks ([\d.]+) s, join")
sealed = re.compile(r"^D55-AB GPU-AB \S+ L\d+ T\d+ forks N(\d+) \[([^\]]+)\] SEALED pass (\d+): wall ([\d.]+) s")
pipe = re.compile(r"^D55-AB GPU-AB PIPE \S+ L\d+ T\d+ forks N(\d+) \[([^\]]+)\] pass (\d+): .*amortized ([\d.]+) proved tok/s; steady state ([\d.]+) tok/s")
usage = re.compile(r"^D55-AB A11 USAGE \S+ L\d+ forks N(\d+) \[([^\]]+)\]: wall ([\d.]+) s.*user ([\d.]+) s \+ sys ([\d.]+) s.*minor faults (\d+)")

vals = collections.defaultdict(dict)  # (metric, pass) -> {label: value}
usage_seq = collections.defaultdict(list)  # label -> [(user, sys, faults)] in call order
with open(path, errors="replace") as f:
    for line in f:
        m = proof.match(line)
        if m and m.group(1) == n_want:
            vals[("proof wall s", int(m.group(3)))][m.group(2)] = float(m.group(4))
            vals[("forks phase s", int(m.group(3)))][m.group(2)] = float(m.group(5))
            continue
        m = sealed.match(line)
        if m and m.group(1) == n_want:
            vals[("sealed wall s", int(m.group(3)))][m.group(2)] = float(m.group(4))
            continue
        m = pipe.match(line)
        if m and m.group(1) == n_want:
            vals[("stream steady tok/s", int(m.group(3)))][m.group(2)] = float(m.group(5))
            vals[("stream amortized tok/s", int(m.group(3)))][m.group(2)] = float(m.group(4))
            continue
        m = usage.match(line)
        if m and m.group(1) == n_want:
            usage_seq[m.group(2)].append((float(m.group(4)), float(m.group(5)), int(m.group(6))))

# the A11 USAGE line precedes its GPU-AB line; a pass's k-th usage line of an arm is pass k
for label, seq in usage_seq.items():
    for p, (u, s, flt) in enumerate(seq):
        vals[("user CPU s", p)][label] = u
        vals[("sys CPU s", p)][label] = s
        vals[("minor faults", p)][label] = flt

metrics = sorted({m for m, _ in vals}, key=lambda m: ["proof wall s", "forks phase s", "sealed wall s", "stream steady tok/s", "stream amortized tok/s", "user CPU s", "sys CPU s", "minor faults"].index(m) if m in ["proof wall s", "forks phase s", "sealed wall s", "stream steady tok/s", "stream amortized tok/s", "user CPU s", "sys CPU s", "minor faults"] else 99)
print(f"# A11 pairs: [{test}] against [{base}], N = {n_want}, {'alternating order' if alternate else 'base first in every pass'} ({path})")
print()
print("| metric | base first: mean change (pairs, favour test) | test first: mean change (pairs, favour test) | order bias solved out | means base / test |")
print("|---|---|---|---|---|")
for metric in metrics:
    higher_better = "tok/s" in metric
    by = {True: [], False: []}  # base_first -> [change]
    bv, tv = [], []
    for (m, p), d in sorted(vals.items()):
        if m != metric or base not in d or test not in d:
            continue
        base_first = (p % 2 == 0) if alternate else True
        ch = d[test] / d[base] - 1.0 if d[base] else float("nan")
        by[base_first].append(ch)
        bv.append(d[base])
        tv.append(d[test])

    def cell(xs):
        if not xs:
            return "—"
        fav = sum(1 for x in xs if (x > 0 if higher_better else x < 0))
        return f"{100 * sum(xs) / len(xs):+.1f}% ({len(xs)}, {fav})"

    solved = "—"
    if by[True] and by[False]:
        solved = f"**{100 * (sum(by[True]) / len(by[True]) + sum(by[False]) / len(by[False])) / 2:+.1f}%**"
    means = f"{sum(bv) / len(bv):.3f} / {sum(tv) / len(tv):.3f}" if bv else "—"
    if metric == "minor faults" and bv:
        means = f"{sum(bv) / len(bv):,.0f} / {sum(tv) / len(tv):,.0f}"
    print(f"| {metric} | {cell(by[True])} | {cell(by[False])} | {solved} | {means} |")
