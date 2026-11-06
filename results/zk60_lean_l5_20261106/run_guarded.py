#!/usr/bin/env python3
"""D63 step L5 Lean lane (2026-11-06): run one command under the zk60 resource guard, detached
(macOS has no setsid / flock; `start_new_session` survives the session), then wait for its .done marker
so a watcher is told when it ends.

usage: run_guarded.py <label> <logfile> <donefile> <cmd...>

The jobs of this lane (WT = this worktree, LAKE = the pinned lake):
  run_guarded.py lean-l5-file file.log file.done LAKE -d WT/formal env lean WT/formal/ZK60Formal/<File>.lean
  run_guarded.py lean-l5-check check.log check.done bash WT/results/zk60_lean_l5_20261106/check_l5.sh
  run_guarded.py lean-l5-rust rust.log rust.done bash WT/results/zk60_lean_l5_20261106/export_corpus.sh
"""
import os
import subprocess
import sys
import time

label, log, done = sys.argv[1], sys.argv[2], sys.argv[3]
cmd = sys.argv[4:]
if os.path.exists(done):
    os.remove(done)
guard = ["python3", "/Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py", "run",
         "--class", "cpu", "--need-gib", "14", "--cap-gib", os.environ.get("L5_CAP_GIB", "24"), "--wait-secs", "14400",
         "--label", label, "--log", log, "--done", done, "--"] + cmd
p = subprocess.Popen(guard, stdin=subprocess.DEVNULL, stdout=open(log + ".guard", "w"), stderr=subprocess.STDOUT,
                     start_new_session=True)
print("started", p.pid, flush=True)
while not os.path.exists(done):
    time.sleep(3)
time.sleep(1)
print("done:", open(done).read().strip(), flush=True)
