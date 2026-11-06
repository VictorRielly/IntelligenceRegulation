#!/usr/bin/env python3
"""A21: the compiler warnings of a build log as (message, file) pairs, line numbers dropped, and those of a second
log that the first does not have. Used to show a build has no NEW warning against the base's build (A20's stage 9).

usage: warn_diff.py <base-log> <log>
"""
import collections
import re
import sys


def pairs(path):
    out = collections.Counter()
    msg = None
    with open(path, errors="replace") as f:
        for ln in f:
            if ln.startswith("warning"):
                msg = ln.strip()
                continue
            m = re.match(r"\s*--> (\S+?):\d+:\d+", ln)
            if m and msg is not None:
                out[(msg, m.group(1))] += 1
                msg = None
    return out


base, mine = pairs(sys.argv[1]), pairs(sys.argv[2])
new = mine - base
gone = base - mine
print(f"warnings with a source location: base {sum(base.values())}, this build {sum(mine.values())}; new {sum(new.values())}, gone {sum(gone.values())}")
for (m, f), n in sorted(new.items()):
    print(f"NEW {n}x {f}: {m}")
for (m, f), n in sorted(gone.items()):
    print(f"gone {n}x {f}: {m}")
