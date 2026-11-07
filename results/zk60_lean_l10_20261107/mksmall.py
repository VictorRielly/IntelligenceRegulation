#!/usr/bin/env python3
"""D63 lane L10 (2026-11-07): a reduced corpus for a quick checker run: the full corpus without the named records
(by default the openings whose every column is checked: `a-honest`, `h-honest`, `h-collast`).

usage: mksmall.py <corpus> <out> [record names to drop]
"""
import sys

src, dst = sys.argv[1], sys.argv[2]
drop = set(sys.argv[3:]) or {"a-honest", "h-honest", "h-collast"}
out, skipping, kept, dropped = [], False, 0, 0
for line in open(src):
    w = line.split(" ", 2)
    if w[0] in ("L10M", "L10PCS", "L10CHK"):
        skipping = w[1] in drop
        if skipping:
            dropped += 1
        else:
            kept += 1
    if not skipping:
        out.append(line)
    if w[0] == "L10END":
        skipping = False
open(dst, "w").write("".join(out))
print(f"mksmall: {kept} records kept, {dropped} dropped -> {dst}")
