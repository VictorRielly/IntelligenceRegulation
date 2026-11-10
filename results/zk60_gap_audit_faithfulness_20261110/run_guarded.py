#!/usr/bin/env python3
"""Gap audit (faithfulness), 2026-11-10: run one command under the zk60 resource guard, detached (macOS has no
setsid / flock; `start_new_session` survives the session), then wait for its .done marker. A copy of
results/zk60_lean_l34_20261109/run_guarded.py with this audit's labels.

usage: run_guarded.py <label> <logfile> <donefile> <cmd...>
  run_guarded.py gap-faith-iter OUT/iterN.log OUT/iterN.done /bin/bash OUT/iter.sh OUT/planN.txt
"""
import os
import subprocess
import sys
import time

label, log, done = sys.argv[1], sys.argv[2], sys.argv[3]
cmd = sys.argv[4:]
if os.path.exists(done):
    os.remove(done)
cap = os.environ.get("GAP_CAP_GIB", "24")
need = str(min(14, int(cap)))
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
