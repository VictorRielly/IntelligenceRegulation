#!/usr/bin/env python3
"""Claude's read-only L62 pre-review (2026-11-16): run one command under the zk60 resource guard, detached
(macOS has no setsid / flock; `start_new_session` survives the session), then wait for its .done marker
so a watcher is told when it ends. A copy of the L63 lane's run_guarded.py (worktree agent-a8b5788916259e1b2,
results/zk60_lean_l63_20261116/run_guarded.py) with this review's label and ZK60_GUARD_POLL_SECS=0.05, so the
job is admitted at a leaf boundary of the long proof batches that poll at 0.05 s.

usage: run_guarded.py <label> <logfile> <donefile> <cmd...>

The jobs of this review (OUT = results/zk60_claude_review_20261116/l62_prereview):
  run_guarded.py lean-l62-review OUT/iterN.log OUT/iterN.done /bin/bash OUT/iter.sh OUT/planN.txt
"""
import os
import subprocess
import sys
import time

label, log, done = sys.argv[1], sys.argv[2], sys.argv[3]
cmd = sys.argv[4:]
if os.path.exists(done):
    os.remove(done)
cap = os.environ.get("L63_CAP_GIB", "24")
need = str(min(14, int(cap)))  # the guard refuses a cap below the need
guard = ["python3", "/Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py", "run",
         "--class", "cpu", "--need-gib", need, "--cap-gib", cap, "--wait-secs", "14400",
         "--label", label, "--log", log, "--done", done, "--"] + cmd
p = subprocess.Popen(guard, stdin=subprocess.DEVNULL, stdout=open(log + ".guard", "w"), stderr=subprocess.STDOUT,
                     start_new_session=True, env=dict(os.environ, ZK60_GUARD_POLL_SECS="0.05"))
print("started", p.pid, flush=True)
while not os.path.exists(done):
    time.sleep(3)
time.sleep(1)
print("done:", open(done).read().strip(), flush=True)
