#!/usr/bin/env python3
"""A11: print each new line of a stage's progress file (filtered) until its .done marker
appears, then print the marker. usage: watch.py <stage> [regex]"""
import os
import re
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
stage = sys.argv[1]
pat = re.compile(sys.argv[2] if len(sys.argv) > 2 else r"rc=|ready|all done|failed|MISSING|present")
prog = os.path.join(HERE, f"{stage}.progress")
done = os.path.join(HERE, f"{stage}.done")
seen = 0
while True:
    if os.path.exists(prog):
        with open(prog, errors="replace") as f:
            lines = f.read().splitlines()
        for l in lines[seen:]:
            if pat.search(l):
                print(l[:220], flush=True)
        seen = len(lines)
    if os.path.exists(done):
        time.sleep(1)
        with open(done) as f:
            print(f"{stage}.done rc={f.read().strip()}", flush=True)
        break
    time.sleep(5)
