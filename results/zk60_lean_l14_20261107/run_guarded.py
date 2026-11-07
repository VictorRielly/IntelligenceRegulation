#!/usr/bin/env python3
"""D63 step L14 Lean lane (2026-11-07): run one command under the zk60 resource guard, detached
(macOS has no setsid / flock; `start_new_session` survives the session), then wait for its .done marker
so a watcher is told when it ends. A copy of results/zk60_lean_l11_20261107/run_guarded.py.

usage: run_guarded.py <label> <logfile> <donefile> <cmd...>

The jobs of this lane (WT = this worktree, OUT = WT/results/zk60_lean_l14_20261107):
  L14_CAP_GIB=10 run_guarded.py lean-l14-file OUT/fileN.log OUT/fileN.done /bin/bash OUT/stage.sh "" <file.lean>
  run_guarded.py lean-l14-check OUT/check.log OUT/check.done /bin/bash OUT/check_l14.sh
"""
import os
import subprocess
import sys
import time

label, log, done = sys.argv[1], sys.argv[2], sys.argv[3]
cmd = sys.argv[4:]
if os.path.exists(done):
    os.remove(done)
cap = os.environ.get("L14_CAP_GIB", "24")
need = str(min(14, int(cap)))  # the guard refuses a cap below the need (a lower cap while iterating on one file)
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
