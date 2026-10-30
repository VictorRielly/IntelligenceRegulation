#!/usr/bin/env python3
"""Token round 19: wait for this lane's turn on the heavy slot (one-shot reads, no signals).

usage: wait_turn.py QUEUE_LOG [--need GIB]

Round 18's wait_turn.py as it stood after the coordinator's 2026-10-30 ~08:20 UTC rule (the round-19 brief repeats it):
returns (exit 0) only when ALL of these hold, re-checked every 30 s:
  * no hold file exists (r19/HOLD, the coordinator's WINDOW_HOLD);
  * no guard process of ASTRA'S APP (label starting with `astra` or `pm-`; any class) is running or waiting.
Every other lane goes through the guard's normal admission (heavy lock + the 11.89 GiB budget), which also enforces the
lean-memory rule. Only a python process whose argv runs the guard counts as a job (a shell loop that mentions the guard
is not one). `--need` is logged only.
"""
import os, re, subprocess, sys, time

R = "/home/victor/IntelligenceRegulation"
T = R + "/results/zk60_token_io_r1_20261017/r19"
HOLDS = [T + "/HOLD", R + "/results/zk60_guard_fix_20261021/WINDOW_HOLD"]


def astra_jobs():
    out = subprocess.run(["ps", "-eo", "comm=,args="], capture_output=True, text=True).stdout.splitlines()
    found = []
    for line in out:
        comm, _, a = line.strip().partition(" ")
        if not comm.startswith("python") or "zk60_resource_guard.py run" not in a or "wait_turn.py" in a:
            continue
        lab = re.search(r"--label (\S+)", a)
        label = lab.group(1) if lab else "?"
        if label.startswith("astra") or label.startswith("pm-"):
            found.append(label)
    return found


def main():
    log = sys.argv[1]
    need = sys.argv[sys.argv.index("--need") + 1] if "--need" in sys.argv else "0"
    last = 0.0
    while True:
        why = [f"hold {h}" for h in HOLDS if os.path.exists(h)] + [f"astra app {j}" for j in astra_jobs()]
        if not why:
            return 0
        if time.time() - last > 300:
            with open(log, "a") as f:
                f.write(time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()) + f" wait (need {need}): " + "; ".join(why) + "\n")
            last = time.time()
        time.sleep(30)


if __name__ == "__main__":
    sys.exit(main())
