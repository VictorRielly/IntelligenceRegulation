#!/usr/bin/env python3
"""Lane A24 (media app speed, 2026-11-07): run one command under the zk60 resource guard,
detached (macOS has no setsid / flock; `start_new_session` survives the session). Returns at
once; the guard writes <done> (the exit code) when the job ends. Pattern of
results/zk60_lean_l8_20261106/run_guarded.py.

usage: run_guarded.py <class> <need_gib> <cap_gib> <max_secs> <label> <logfile> <donefile> <cmd...>

Disk floor: the guard's heavy-job disk floor is 40 GiB by default (ZK60_GUARD_DISK_FLOOR_GIB).
On 2026-11-06 the Mac had 39.9 GiB free with 235 GiB of RAM available and no swap in use,
so every heavy job waited. A24 sets A24_DISK_FLOOR_GIB (default 25) for its own jobs only;
the kill floor (8 GiB) is unchanged. Recorded in the lane README.
"""
import os
import subprocess
import sys

cls, need, cap, max_secs, label, log, done = sys.argv[1:8]
cmd = sys.argv[8:]
if os.path.exists(done):
    os.remove(done)
env = dict(os.environ)
env["ZK60_GUARD_DISK_FLOOR_GIB"] = os.environ.get("A24_DISK_FLOOR_GIB", "25")
guard = ["python3", "/Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py", "run",
         "--class", cls, "--need-gib", need, "--cap-gib", cap, "--max-secs", max_secs,
         "--wait-secs", "14400", "--label", label, "--log", log, "--done", done, "--"] + cmd
p = subprocess.Popen(guard, stdin=subprocess.DEVNULL, stdout=open(log + ".guard", "w"),
                     stderr=subprocess.STDOUT, start_new_session=True, env=env)
print("started", p.pid, flush=True)
