#!/usr/bin/env python3
"""D63 lane L54 Lean lane (2026-11-10): run one command under the zk60 resource guard, detached
(macOS has no setsid / flock; `start_new_session` survives the session), then wait for its .done marker
so a watcher is told when it ends. A copy of results/zk60_lean_l52_20261110/run_guarded.py with this lane's labels.

usage: run_guarded.py <label> <logfile> <donefile> <cmd...>

The jobs of this lane (WT = this worktree, OUT = WT/results/zk60_lean_l54_20261110):
  run_guarded.py lean-l54-iter OUT/iterN.log OUT/iterN.done /bin/bash OUT/iter.sh [plan]
  run_guarded.py lean-l54-check OUT/check_run.log OUT/check.done /bin/bash OUT/check_l54.sh
Every job runs at cap 36 GiB, need 24 (finding L42-8), with LEAN_NUM_THREADS=4 (set in iter.sh / check_l54.sh).
"""
import os
import subprocess
import sys
import time

label, log, done = sys.argv[1], sys.argv[2], sys.argv[3]
cmd = sys.argv[4:]
if os.path.exists(done):
    os.remove(done)
cap = os.environ.get("L54_CAP_GIB", "36")
need = os.environ.get("L54_NEED_GIB", "24")
guard = ["python3", "/Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py", "run",
         "--class", "cpu", "--need-gib", need, "--cap-gib", cap, "--wait-secs", "14400",
         "--label", label, "--log", log, "--done", done, "--"] + cmd
p = subprocess.Popen(guard, stdin=subprocess.DEVNULL, stdout=open(log + ".guard", "w"), stderr=subprocess.STDOUT,
                     start_new_session=True)
print("started", p.pid, flush=True)
while not os.path.exists(done):
    time.sleep(3)
time.sleep(1)
print("done:", open(done).read().strip(), flush=True)
