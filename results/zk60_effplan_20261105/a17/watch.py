#!/usr/bin/env python3
"""A17: print a stage's NEW progress lines (filtered) until it ends (`all done` or a new `.done` file).
Lines already in the progress file when the watcher starts are skipped (a progress file is appended to by
every attempt).

usage: watch.py <stage> [poll seconds]
"""
import os
import re
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
stage = sys.argv[1]
poll = float(sys.argv[2]) if len(sys.argv) > 2 else 5.0
prog = os.path.join(HERE, f"{stage}.progress")
done = os.path.join(HERE, f"{stage}.done")
keep = re.compile(r"rc=|ready|all done|FAIL|MISSING|panicked|error|test result")
seen = len(open(prog).read().splitlines()) if os.path.exists(prog) else 0
done_at_start = os.path.getmtime(done) if os.path.exists(done) else None
while True:
    lines = open(prog).read().splitlines() if os.path.exists(prog) else []
    new = lines[seen:]
    for line in new:
        if keep.search(line):
            print(line[:220], flush=True)
    seen = len(lines)
    if any("all done" in l for l in new):
        break
    if os.path.exists(done) and os.path.getmtime(done) != done_at_start:
        print(f"{stage}.done: {open(done).read().strip()}", flush=True)
        break
    time.sleep(poll)
