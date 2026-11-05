#!/usr/bin/env python3
"""A13: paired changes of the one-request (SEALED) calls' own clocks, by arm order.

usage: seal_pairs.py <d55.log> <base-label> <test-label> [--n 6]

Reads the harness's per-call lines
  `D55-AB A13 SEALED <name> L<l> N<n> [<label>]: wall <s> s; sealing pass <s> s (<c> cores busy, <cpu> CPU-s);
   prove call <s> s: preflight <s>, commit <s>, forks <s>, join <s> s; <p>/<l> forks parked ...`
(the k-th line of an arm is its pass k), pairs base and test pass by pass, and, as `a11/pairs.py --alternate`
does, takes the base as first in even passes and second in odd ones; the order bias cancels in the mean of the
two orders' means.
"""
import collections
import re
import sys

a = sys.argv[1:]
path, base, test = a[0], a[1], a[2]
n_want = a[a.index("--n") + 1] if "--n" in a else "6"
pat = re.compile(
    r"^D55-AB A13 SEALED \S+ L\d+ N(\d+) \[([^\]]*)\]: wall ([\d.]+) s; sealing pass ([\d.]+) s \(([\d.]+) cores busy, ([\d.]+) CPU-s\); "
    r"prove call ([\d.]+) s: preflight ([\d.]+), commit ([\d.]+), forks ([\d.]+), join ([\d.]+) s; (\d+)/\d+ forks parked"
)
names = ["one request wall s", "sealing pass s", "sealing CPU-s", "prove call s", "forks phase (of the request) s", "preflight + commit s"]
seq = collections.defaultdict(list)
with open(path, errors="replace") as f:
    for line in f:
        m = pat.match(line)
        if not m or m.group(1) != n_want:
            continue
        v = [float(m.group(i)) for i in (3, 4, 6, 7, 10)]
        v.append(float(m.group(8)) + float(m.group(9)))
        seq[m.group(2)].append(v)
b, t = seq.get(base, []), seq.get(test, [])
print(f"# A13 one-request clocks: [{test}] against [{base}], N = {n_want}, alternating order ({path})")
print()
print("| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |")
print("|---|---|---|---|---|")
for i, name in enumerate(names):
    by = {True: [], False: []}
    for p in range(min(len(b), len(t))):
        by[p % 2 == 0].append(t[p][i] / b[p][i] - 1.0 if b[p][i] else float("nan"))

    def cell(xs):
        if not xs:
            return "—"
        return f"{100 * sum(xs) / len(xs):+.1f}% ({len(xs)}, {sum(1 for x in xs if x < 0)})"

    solved = f"**{100 * (sum(by[True]) / len(by[True]) + sum(by[False]) / len(by[False])) / 2:+.1f}%**" if by[True] and by[False] else "—"
    k = min(len(b), len(t))
    means = f"{sum(x[i] for x in b[:k]) / k:.3f} / {sum(x[i] for x in t[:k]) / k:.3f}" if k else "—"
    print(f"| {name} | {cell(by[True])} | {cell(by[False])} | {solved} | {means} |")
