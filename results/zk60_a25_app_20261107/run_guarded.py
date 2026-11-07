#!/usr/bin/env python3
"""Lane A25 (media app W16R2 dev profile, 2026-11-07): run one command under the zk60 resource
guard, detached (macOS has no setsid / flock; `start_new_session` survives the session).
Returns at once; the guard writes <done> (the exit code) when the job ends. A24's
run_guarded.py WITHOUT its disk-floor override: the guard's own floors apply (coordinator,
2026-11-07: do not lower the disk floor).

usage: run_guarded.py <class> <need_gib> <cap_gib> <max_secs> <label> <logfile> <donefile> <cmd...>
"""
import os
import subprocess
import sys

cls, need, cap, max_secs, label, log, done = sys.argv[1:8]
cmd = sys.argv[8:]
if os.path.exists(done):
    os.remove(done)
guard = ["python3", "/Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py", "run",
         "--class", cls, "--need-gib", need, "--cap-gib", cap, "--max-secs", max_secs,
         "--wait-secs", "14400", "--label", label, "--log", log, "--done", done, "--"] + cmd
p = subprocess.Popen(guard, stdin=subprocess.DEVNULL, stdout=open(log + ".guard", "w"),
                     stderr=subprocess.STDOUT, start_new_session=True)
print("started", p.pid, flush=True)
