#!/usr/bin/env python3
"""Coordinator hold #2 (20:50Z 2026-10-17): exit 0 (released) when EITHER it is >= 22:00 UTC, OR each of the
heavy-queue jobs r5-ladder8b-T128-*, gzc-stack-s0*, gzc-stack-s4* has a completion record in the guard
history (ts_end >= 20:45Z) and none of them is live in the guard status. Exit 1 otherwise.
Limitation: the guard status lists only admitted jobs, so a second queued job with one of these prefixes
after the first completed would not be seen; the 22:00 deadline bounds the hold either way."""
import datetime as dt
import json
import subprocess
import sys

PREFIXES = ("r5-ladder8b-T128-", "gzc-stack-s0", "gzc-stack-s4")
SINCE = "2026-10-17T20:45:00Z"
DEADLINE = dt.datetime(2026, 10, 17, 22, 0, 0, tzinfo=dt.timezone.utc)
HIST = "/home/victor/IntelligenceRegulation/results/zk60_resource_guard/history.jsonl"
GUARD = "/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py"

if dt.datetime.now(dt.timezone.utc) >= DEADLINE:
    print("hold2: released by the 22:00 UTC deadline")
    sys.exit(0)
done = set()
with open(HIST) as f:
    for line in f:
        try:
            r = json.loads(line)
        except ValueError:
            continue
        lab, te = r.get("label") or "", r.get("ts_end") or ""
        for p in PREFIXES:
            if lab.startswith(p) and te >= SINCE:
                done.add(p)
st = subprocess.run(["python3", GUARD, "status"], capture_output=True, text=True).stdout
live = [ln.split()[1] for ln in st.splitlines() if ln.startswith("  job  ") and len(ln.split()) > 1
        and ln.split()[1].startswith(PREFIXES)]
if len(done) == len(PREFIXES) and not live:
    print(f"hold2: released (completed {sorted(done)}, none live)")
    sys.exit(0)
sys.exit(1)
