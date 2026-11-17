#!/usr/bin/env python3
"""D63 lane L63 Lean lane (2026-11-16): run one command under the zk60 resource guard, detached
(macOS has no setsid / flock; `start_new_session` survives the session), then wait for its .done marker
so a watcher is told when it ends. A copy of results/zk60_lean_l26_20261107/run_guarded.py with this lane's labels.

usage: run_guarded.py <label> <logfile> <donefile> <cmd...>

The jobs of this lane (WT = this worktree, OUT = WT/results/zk60_lean_l63_20261116):
  run_guarded.py lean-l63-iter OUT/iterN.log OUT/iterN.done /bin/bash OUT/iter.sh [plan]
  run_guarded.py lean-l63-check OUT/check.log OUT/check.done /bin/bash OUT/check_l63.sh
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
# the guard's default poll (the coordinator ended the 0.05 s fast-poll rule on 2026-11-16; L63_POLL_SECS, e.g. 0.5,
# overrides it for one job that loses a boundary to a long leaf)
env = dict(os.environ)
env.pop("ZK60_GUARD_POLL_SECS", None)
if os.environ.get("L63_POLL_SECS"):
    env["ZK60_GUARD_POLL_SECS"] = os.environ["L63_POLL_SECS"]
p = subprocess.Popen(guard, stdin=subprocess.DEVNULL, stdout=open(log + ".guard", "w"), stderr=subprocess.STDOUT,
                     start_new_session=True, env=env)
print("started", p.pid, flush=True)
while not os.path.exists(done):
    time.sleep(3)
time.sleep(1)
print("done:", open(done).read().strip(), flush=True)
