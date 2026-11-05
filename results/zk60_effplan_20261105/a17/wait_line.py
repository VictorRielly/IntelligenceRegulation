#!/usr/bin/env python3
"""A17: wait until a stage's progress file gains a line matching a pattern (or `all done`), at most <secs>;
print the new matching lines.

usage: wait_line.py <stage> <regex> [secs]
"""
import os
import re
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
stage, pat = sys.argv[1], re.compile(sys.argv[2])
secs = float(sys.argv[3]) if len(sys.argv) > 3 else 170.0
prog = os.path.join(HERE, f"{stage}.progress")
read = lambda: open(prog).read().splitlines() if os.path.exists(prog) else []
seen = len(read())
t0 = time.time()
while time.time() - t0 < secs:
    new = read()[seen:]
    hit = [l for l in new if pat.search(l) or "all done" in l]
    if hit:
        for l in hit:
            print(l[:240])
        break
    time.sleep(3)
else:
    print(f"(no new line matching {sys.argv[2]!r} after {secs:.0f} s)")
