#!/usr/bin/env python3
"""D55 (2026-11-01): the detached runner (the Mac's no-hangup recipe: python3, start_new_session).

Runs, one after another, each a bash leaf whose heavy steps go through the ONE shared resource guard:
  1. the A/B on one request (d55_ab.sh: W16 8B T128, L=32, N = 1,2,4,6, 3 warm passes);
  2. the gate chain (d55_gates.sh).
Logs in logs/; logs/run_d55.done holds one "<job> <exit>" line each, then "ALL <0|first failure>".
Usage: python3 run_d55.py <test binary>   (the parent prints the detached pid and exits)."""
import os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
LOGS = os.path.join(HERE, "logs")


def child(binary):
    os.makedirs(LOGS, exist_ok=True)
    done = os.path.join(LOGS, "run_d55.done")
    part = done + ".partial"
    for p in (done, part):
        if os.path.exists(p):
            os.remove(p)
    jobs = [
        ("ab", ["bash", os.path.join(HERE, "d55_ab.sh"), binary, "l32", "32", "1,2,4,6", "3", "40", "120"]),
        ("gates", ["bash", os.path.join(HERE, "d55_gates.sh"), "gates"]),
    ]
    only = os.environ.get("D55_JOBS")
    if only:
        jobs = [j for j in jobs if j[0] in only.split(",")]
    first = None
    for name, cmd in jobs:
        with open(os.path.join(LOGS, f"run_{name}.out"), "w") as out:
            rc = subprocess.run(cmd, stdout=out, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL).returncode
        with open(part, "a") as f:
            f.write(f"{name} {rc}\n")
        if rc != 0 and first is None:
            first = name
    os.replace(part, done)
    with open(done, "a") as f:
        f.write(f"ALL {0 if first is None else first}\n")


if __name__ == "__main__":
    if "--child" in sys.argv:
        child(sys.argv[sys.argv.index("--child") + 1])
    else:
        os.makedirs(LOGS, exist_ok=True)
        p = subprocess.Popen([sys.executable, os.path.abspath(__file__), "--child", sys.argv[1]], start_new_session=True,
                             stdin=subprocess.DEVNULL, stdout=open(os.path.join(LOGS, "run_d55.runner.out"), "w"), stderr=subprocess.STDOUT)
        print("detached D55 runner pid", p.pid)
