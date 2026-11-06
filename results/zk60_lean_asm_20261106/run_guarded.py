#!/usr/bin/env python3
"""D63 assembly Lean lane (2026-11-06): run one command under the zk60 resource guard, detached
(macOS has no setsid / flock; `start_new_session` survives the session), then wait for its .done marker
so a watcher is told when it ends.

usage: run_guarded.py <label> <logfile> <donefile> <cmd...>

The jobs of this lane (WT = this worktree, LAKE = the pinned lake):
  run_guarded.py lean-asm-file file.log file.done LAKE -d WT/formal env lean WT/formal/ZK60Formal/Assembly.lean
  run_guarded.py lean-asm-full full.log full.done LAKE -d WT/formal build
  run_guarded.py lean-asm-axioms axioms.log axioms.done LAKE -d WT/formal env lean \
    WT/results/zk60_lean_asm_20261106/axioms_asm.lean
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
         "--class", "cpu", "--need-gib", "14", "--cap-gib", "24", "--wait-secs", "14400",
         "--label", label, "--log", log, "--done", done, "--"] + cmd
p = subprocess.Popen(guard, stdin=subprocess.DEVNULL, stdout=open(log + ".guard", "w"), stderr=subprocess.STDOUT,
                     start_new_session=True)
print("started", p.pid, flush=True)
while not os.path.exists(done):
    time.sleep(5)
time.sleep(1)
print("done:", open(done).read().strip(), flush=True)
