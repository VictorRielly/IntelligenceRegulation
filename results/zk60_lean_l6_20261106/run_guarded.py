#!/usr/bin/env python3
"""D63 step L6 Lean lane (2026-11-06): run one command under the zk60 resource guard, detached
(macOS has no setsid / flock; `start_new_session` survives the session), then wait for its .done marker
so a watcher is told when it ends. A copy of results/zk60_lean_l5_20261106/run_guarded.py.

usage: run_guarded.py <label> <logfile> <donefile> <cmd...>

The jobs of this lane (WT = this worktree, OUT = WT/results/zk60_lean_l6_20261106):
  run_guarded.py lean-l6-file OUT/fileN.log OUT/fileN.done /bin/bash OUT/lean_file.sh WT/formal/ZK60Formal/<File>.lean
  run_guarded.py lean-l6-rust OUT/rust.log OUT/rust.done /bin/bash OUT/export_corpus.sh
  run_guarded.py lean-l6-check OUT/check.log OUT/check.done /bin/bash OUT/check_l6.sh
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
         "--class", "cpu", "--need-gib", "14", "--cap-gib", os.environ.get("L6_CAP_GIB", "24"), "--wait-secs", "14400",
         "--label", label, "--log", log, "--done", done, "--"] + cmd
p = subprocess.Popen(guard, stdin=subprocess.DEVNULL, stdout=open(log + ".guard", "w"), stderr=subprocess.STDOUT,
                     start_new_session=True)
print("started", p.pid, flush=True)
while not os.path.exists(done):
    time.sleep(3)
time.sleep(1)
print("done:", open(done).read().strip(), flush=True)
