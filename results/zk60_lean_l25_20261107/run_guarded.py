#!/usr/bin/env python3
"""D63 Lean lane L25 (2026-11-07, the parts' honest provers): run one command under the zk60 resource guard, detached
(macOS has no setsid / flock; `start_new_session` survives the session), then wait for its .done marker so a watcher
is told when it ends. A copy of results/zk60_lean_l16_20261107/run_guarded.py with this lane's labels.

usage: run_guarded.py <label> <logfile> <donefile> <cmd...>

The jobs of this lane (WT = this worktree, OUT = WT/results/zk60_lean_l25_20261107):
  run_guarded.py lean-l25-prebuild OUT/prebuild.log OUT/prebuild.done /bin/bash OUT/prebuild.sh
  run_guarded.py lean-l25-file OUT/fileN.log OUT/fileN.done /bin/bash OUT/stage.sh "" <file.lean>
  run_guarded.py lean-l25-check OUT/check.log OUT/check.done /bin/bash OUT/check_l25.sh
"""
import os
import subprocess
import sys
import time

label, log, done = sys.argv[1], sys.argv[2], sys.argv[3]
cmd = sys.argv[4:]
if os.path.exists(done):
    os.remove(done)
cap = os.environ.get("L25_CAP_GIB", "24")
need = str(min(14, int(cap)))  # the guard refuses a cap below the need
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
