#!/usr/bin/env python3
"""A19: per-arm means of the `D55-AB A19 PROD ... pass <p>:` lines of `a19_production_d55_ab` (the measured passes,
not the cold call): one request's wall, its sealing pass (and the loads and witness builds inside it), the prove call
and its forks phase, the directory-to-receipt time, the parts handed and parked, the witness bytes the budget counted,
and the peak footprint (min-max).

usage: prod_table.py <log> [<log> ...]
"""
import collections
import re
import sys

line = re.compile(
    r"^D55-AB A19 PROD \S+ L\d+ N\d+ \[(?P<arm>[^\]]+)\] pass \d+: wall (?P<wall>[\d.]+) s .*?sealing pass (?P<seal>[\d.]+) s "
    r"\(loads (?P<load>[\d.]+) s beside it, witnesses (?P<wit>[\d.]+) s.*?window (?P<win>\d+), (?P<handed>\d+) parts handed "
    r"\((?P<pgb>[\d.]+) GB budgeted\), (?P<kept>\d+) witnesses kept \((?P<kgb>[\d.]+) GB\); blocks (?P<blocks>\S+) "
    r"\(reload (?P<reload>[\d.]+) s\); prove call (?P<prove>[\d.]+) s: .*?forks (?P<forks>[\d.]+), join .*?; (?P<parked>\d+) forks parked"
    r".*?(?P<back>\d+) taken back whole.*?directory to receipt written (?P<dir>[\d.]+) s.*?peak (?P<peak>[\d.]+) GiB"
)
rows = collections.defaultdict(list)
for path in sys.argv[1:]:
    with open(path, errors="replace") as f:
        for ln in f:
            m = line.match(ln)
            if m:
                rows[(path.split("/")[-1], m.group("arm"))].append(m.groupdict())

print("| log | arm | passes | one request s | sealing pass s (loads / witnesses) | blocks (reload s) | prove call s | forks s | directory to receipt s | parts handed / parked / taken back | budgeted GB (parts + kept) | peak footprint GiB |")
print("|---|---|---:|---:|---|---|---:|---:|---:|---|---|---|")
for (log, arm), rs in rows.items():
    mean = lambda k: sum(float(r[k]) for r in rs) / len(rs)
    peaks = [float(r["peak"]) for r in rs]
    print(
        f"| {log} | {arm} | {len(rs)} | {mean('wall'):.3f} | {mean('seal'):.3f} ({mean('load'):.2f} / {mean('wit'):.2f}) | {rs[0]['blocks']} ({mean('reload'):.3f}) "
        f"| {mean('prove'):.3f} | {mean('forks'):.3f} | {mean('dir'):.3f} | {mean('handed'):.0f} / {mean('parked'):.1f} / {mean('back'):.1f} "
        f"| {mean('pgb'):.1f} + {mean('kgb'):.1f} | {min(peaks):.1f}-{max(peaks):.1f} |"
    )
