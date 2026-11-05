#!/usr/bin/env python3
"""A15: paired changes of the sealing pass's own clocks and CPU, by arm order (as `a11/pairs.py --alternate`).

usage: seal_pairs.py <d55.log> <base-label> <test-label> [--n 6]

Reads the harness's A15 lines
  `D55-AB A15 SEALED <name> L<l> N<n> [<label>]: sealing pass <s> s in <pool>: user <u> s + sys <s> s = ...;
   csw voluntary <v>, involuntary <i>; minor faults <f>`         (one request from its input: its sealing pass)
  `D55-AB A15 PIPE-SEAL <name> L<l> N<n> [<label>] request <q>: sealing pass <s> s in <pool>`   (a stream's)
The k-th SEALED line of an arm is its pass k; the k-th run of PIPE-SEAL lines (request 0 starts one) is its
pass k: request 0's sealing pass runs alone, the later ones beside the previous request's forks. The base is
first in even passes and second in odd ones; the order bias cancels in the mean of the two orders' means.
"""
import collections
import re
import sys

a = sys.argv[1:]
path, base, test = a[0], a[1], a[2]
n_want = a[a.index("--n") + 1] if "--n" in a else "6"
sealed = re.compile(
    r"^D55-AB A15 SEALED \S+ L\d+ N(\d+) \[([^\]]*)\]: sealing pass ([\d.]+) s in .*?: user ([\d.]+) s \+ sys ([\d.]+) s = [\d.]+ cores; "
    r"csw voluntary (\d+), involuntary (\d+); minor faults (\d+)"
)
pipe = re.compile(r"^D55-AB A15 PIPE-SEAL \S+ L\d+ N(\d+) \[([^\]]*)\] request (\d+): sealing pass ([\d.]+) s")
names = ["one request: sealing pass s", "one request: sealing user CPU s", "one request: sealing sys CPU s", "one request: sealing involuntary csw", "stream: request 0's sealing pass s (alone)", "stream: requests 1.. sealing pass s (beside the forks)"]
seq = collections.defaultdict(list)
pipes = collections.defaultdict(list)  # label -> [[request seconds...] per pass]
with open(path, errors="replace") as f:
    for line in f:
        m = sealed.match(line)
        if m and m.group(1) == n_want:
            seq[m.group(2)].append([float(m.group(3)), float(m.group(4)), float(m.group(5)), float(m.group(7))])
            continue
        m = pipe.match(line)
        if m and m.group(1) == n_want:
            if int(m.group(3)) == 0:
                pipes[m.group(2)].append([])
            if pipes[m.group(2)]:
                pipes[m.group(2)][-1].append(float(m.group(4)))


def rows(label):
    out = []
    s, p = seq.get(label, []), pipes.get(label, [])
    for k in range(max(len(s), len(p))):
        r = s[k] if k < len(s) else [float("nan")] * 4
        q = p[k] if k < len(p) else []
        r = r + [q[0] if q else float("nan"), sum(q[1:]) / len(q[1:]) if len(q) > 1 else float("nan")]
        out.append(r)
    return out


b, t = rows(base), rows(test)
print(f"# A15 sealing-pass clocks: [{test}] against [{base}], N = {n_want}, alternating order ({path})")
print()
print("| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |")
print("|---|---|---|---|---|")
for i, name in enumerate(names):
    by = {True: [], False: []}
    bv, tv = [], []
    for p in range(min(len(b), len(t))):
        x, y = b[p][i], t[p][i]
        if x != x or y != y or not x:
            continue
        by[p % 2 == 0].append(y / x - 1.0)
        bv.append(x)
        tv.append(y)

    def cell(xs):
        if not xs:
            return "—"
        return f"{100 * sum(xs) / len(xs):+.1f}% ({len(xs)}, {sum(1 for x in xs if x < 0)})"

    solved = f"**{100 * (sum(by[True]) / len(by[True]) + sum(by[False]) / len(by[False])) / 2:+.1f}%**" if by[True] and by[False] else "—"
    means = f"{sum(bv) / len(bv):.3f} / {sum(tv) / len(tv):.3f}" if bv else "—"
    print(f"| {name} | {cell(by[True])} | {cell(by[False])} | {solved} | {means} |")
