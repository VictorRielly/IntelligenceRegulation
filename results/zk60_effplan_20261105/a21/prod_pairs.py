#!/usr/bin/env python3
"""A21: paired changes of production's request clocks (`D55-AB A19 PROD ... pass <p>:` lines of
`a19_production_d55_ab`), by arm order, as A20's `prod_pairs.py` does, with the prove call's preflight (its CS-6
re-hash of every block digest) as a clock of its own. For every pass holding both arms, test / base - 1 per clock;
the base runs first in even passes and second in odd ones (`HL_D55_AB_ALTERNATE=1`), and the order bias cancels in
the mean of the two orders' means. The last column counts the pairs (of all) in which the test arm was lower.

usage: prod_pairs.py <log> <base-label> <test-label>
"""
import collections
import re
import sys

path, base, test = sys.argv[1], sys.argv[2], sys.argv[3]
line = re.compile(
    r"^D55-AB A19 PROD \S+ L\d+ N\d+ \[(?P<arm>[^\]]+)\] pass (?P<p>\d+): wall (?P<wall>[\d.]+) s .*?sealing pass (?P<seal>[\d.]+) s "
    r"\(loads (?P<load>[\d.]+) s beside it, witnesses (?P<wit>[\d.]+) s.*?prove call (?P<prove>[\d.]+) s: preflight (?P<pre>[\d.]+), "
    r"commit (?P<commit>[\d.]+), forks (?P<forks>[\d.]+), join "
    r".*?directory to receipt written (?P<dir>[\d.]+) s.*?peak (?P<peak>[\d.]+) GiB"
    r"(?:.*?the pass waited (?P<wait>[\d.]+) s for its loads \((?P<ahead>\d+) ahead\); receipt write (?P<write>[\d.]+) s \((?P<writers>\d+) writers\))?"
)
names = [
    ("wall", "one request from its input s"),
    ("seal", "its sealing pass s"),
    ("load", "loads beside it (summed) s"),
    ("wit", "witness builds (summed) s"),
    ("wait", "the pass's wait for its loads s"),
    ("prove", "its prove call s"),
    ("pre", "its preflight (CS-6 re-hash) s"),
    ("commit", "its commit phase s"),
    ("forks", "its forks phase s"),
    ("write", "the receipt write s"),
    ("dir", "directory to receipt written s"),
    ("peak", "peak footprint GiB"),
]
vals = collections.defaultdict(dict)  # (key, pass) -> {arm: value}
with open(path, errors="replace") as f:
    for ln in f:
        m = line.match(ln)
        if not m:
            continue
        for k, _ in names:
            v = m.group(k)
            if v is not None:
                vals[(k, int(m.group("p")))][m.group("arm")] = float(v)
print(f"# A21 production pairs: [{test}] against [{base}], alternating order ({path})")
print()
print("| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test | test lower in |")
print("|---|---|---|---|---|---|")
for k, title in names:
    by = {True: [], False: []}
    bv, tv = [], []
    for (kk, p), d in sorted(vals.items()):
        if kk != k or base not in d or test not in d:
            continue
        bv.append(d[base])
        tv.append(d[test])
        if d[base]:
            by[p % 2 == 0].append(d[test] / d[base] - 1.0)

    def cell(xs):
        if not xs:
            return "—"
        return f"{100 * sum(xs) / len(xs):+.1f}% ({len(xs)}, {sum(1 for x in xs if x < 0)})"

    solved = f"**{100 * (sum(by[True]) / len(by[True]) + sum(by[False]) / len(by[False])) / 2:+.1f}%**" if by[True] and by[False] else "—"
    means = f"{sum(bv) / len(bv):.3f} / {sum(tv) / len(tv):.3f}" if bv else "—"
    allp = by[True] + by[False]
    lower = f"{sum(1 for x in allp if x < 0)} of {len(allp)}" if allp else "—"
    print(f"| {title} | {cell(by[True])} | {cell(by[False])} | {solved} | {means} | {lower} |")
