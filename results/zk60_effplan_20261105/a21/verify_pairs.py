#!/usr/bin/env python3
"""A21: paired changes of the verifier's clocks (`A21-VERIFY ... [arm] pass <p>: verify <s> s ...; read_fork_receipt
alone <s> s` lines of `a21_verifier_ab`), by arm order: the arms run in their listed order in even passes and reversed
in odd ones, and the order bias cancels in the mean of the two orders' means.

usage: verify_pairs.py <log> <base-label> <test-label>
"""
import collections
import re
import sys

path, base, test = sys.argv[1], sys.argv[2], sys.argv[3]
line = re.compile(r"^A21-VERIFY \S+ L\d+ \[(?P<arm>[^\]]+)\] pass (?P<p>\d+): verify (?P<verify>[\d.]+) s .*?read_fork_receipt alone (?P<read>[\d.]+) s")
names = [("verify", "verify_run_with_forks_from_dir s"), ("read", "read_fork_receipt alone (frames read and SHA-256'd) s")]
vals = collections.defaultdict(dict)
with open(path, errors="replace") as f:
    for ln in f:
        m = line.match(ln)
        if m:
            for k, _ in names:
                vals[(k, int(m.group("p")))][m.group("arm")] = float(m.group(k))
print(f"# A21 verifier pairs: [{test}] against [{base}], alternating order ({path})")
print()
print("| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |")
print("|---|---|---|---|---|")
for k, title in names:
    by = {True: [], False: []}
    bv, tv = [], []
    for (kk, p), d in sorted(vals.items()):
        if kk != k or base not in d or test not in d:
            continue
        bv.append(d[base])
        tv.append(d[test])
        by[p % 2 == 0].append(d[test] / d[base] - 1.0)

    def cell(xs):
        if not xs:
            return "—"
        return f"{100 * sum(xs) / len(xs):+.1f}% ({len(xs)}, {sum(1 for x in xs if x < 0)})"

    solved = f"**{100 * (sum(by[True]) / len(by[True]) + sum(by[False]) / len(by[False])) / 2:+.1f}%**" if by[True] and by[False] else "—"
    means = f"{sum(bv) / len(bv):.3f} / {sum(tv) / len(tv):.3f}" if bv else "—"
    print(f"| {title} | {cell(by[True])} | {cell(by[False])} | {solved} | {means} |")
