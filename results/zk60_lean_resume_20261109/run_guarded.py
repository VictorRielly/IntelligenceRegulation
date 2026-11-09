#!/usr/bin/env python3
"""Coordinator, 2026-11-09: run one command under the zk60 resource guard, detached (macOS has no setsid / flock;
`start_new_session` survives the session), then wait for its .done marker. A copy of
results/zk60_lean_l25_20261107/run_guarded.py with a class argument.

usage: run_guarded.py <class> <need_gib> <cap_gib> <label> <logfile> <donefile> <cmd...>
"""
import os
import subprocess
import sys
import time

klass, need, cap, label, log, done = sys.argv[1:7]
cmd = sys.argv[7:]
if os.path.exists(done):
    os.remove(done)
guard = ["python3", "/Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py", "run",
         "--class", klass, "--need-gib", need, "--cap-gib", cap, "--wait-secs", "14400",
         "--label", label, "--log", log, "--done", done, "--"] + cmd
p = subprocess.Popen(guard, stdin=subprocess.DEVNULL, stdout=open(log + ".guard", "w"), stderr=subprocess.STDOUT,
                     start_new_session=True)
print("started", p.pid, flush=True)
while not os.path.exists(done):
    time.sleep(3)
time.sleep(1)
print("done:", open(done).read().strip(), flush=True)
