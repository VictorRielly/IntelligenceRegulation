#!/usr/bin/env python3
"""Coordinator hold #3 (01:4xZ 2026-10-18): exit 0 (released) when EITHER it is >= 05:30 UTC 2026-10-18, OR the
privacy gate's L22 chain has finished: results/zk60_gate_tinyllama_20261017/r5b/light_queue.finished exists
(written after its last L22 pass, or when that queue stops early) AND no job labelled tl-r5b-l22-* is live in the
guard status. Exit 1 otherwise. (Queued jobs are invisible in the status; the finished marker covers them.)"""
import datetime as dt
import subprocess
import sys
from pathlib import Path

DEADLINE = dt.datetime(2026, 10, 18, 5, 30, 0, tzinfo=dt.timezone.utc)
MARK = Path("/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017/r5b/light_queue.finished")
GUARD = "/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py"

if dt.datetime.now(dt.timezone.utc) >= DEADLINE:
    print("hold3: released by the 05:30 UTC deadline")
    sys.exit(0)
st = subprocess.run(["python3", GUARD, "status"], capture_output=True, text=True).stdout
live = [ln.split()[1] for ln in st.splitlines() if ln.startswith("  job  ") and len(ln.split()) > 1
        and ln.split()[1].startswith("tl-r5b-l22-")]
if MARK.exists() and not live:
    print(f"hold3: released (gate L22 chain finished: {MARK.name} exists, no tl-r5b-l22-* live)")
    sys.exit(0)
sys.exit(1)
