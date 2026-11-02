#!/usr/bin/env python3
"""D60 (2026-11-02): the detached runner (the Mac's no-hangup recipe: python3, start_new_session).

Runs, one after another, each a bash leaf whose heavy steps go through the ONE shared resource guard:
  1. the gate chain (d60_gates.sh), which writes logs/chain/binary.path;
  2. the A/B on one request (d60_ab.sh: R13 8B T128, L = 32, serial against the registered D55 profile at
     N = 6, both orders), on the chain's binary.
logs/run_d60.done holds one "<job> <exit>" line each, then "ALL <0|first failure>".
Usage: python3 run_d60.py [jobs, comma-separated; default gates,ab]   (the parent prints the pid and exits)."""
import os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
LOGS = os.path.join(HERE, "logs")


def child(jobs):
    os.makedirs(LOGS, exist_ok=True)
    done = os.path.join(LOGS, "run_d60.done")
    part = done + ".partial"
    for p in (done, part):
        if os.path.exists(p):
            os.remove(p)
    first = None
    for name in jobs:
        if name == "gates":
            cmd = ["bash", os.path.join(HERE, "d60_gates.sh")]
        elif name == "ab":
            binary = open(os.path.join(LOGS, "chain", "binary.path")).read().strip()
            cmd = ["bash", os.path.join(HERE, "d60_ab.sh"), binary, "4"]
        else:
            raise SystemExit(f"unknown job {name}")
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
        child(sys.argv[sys.argv.index("--child") + 1].split(","))
    else:
        jobs = sys.argv[1] if len(sys.argv) > 1 else "gates,ab"
        os.makedirs(LOGS, exist_ok=True)
        p = subprocess.Popen([sys.executable, os.path.abspath(__file__), "--child", jobs], start_new_session=True,
                             stdin=subprocess.DEVNULL, stdout=open(os.path.join(LOGS, "run_d60.runner.out"), "w"), stderr=subprocess.STDOUT)
        print("detached D60 runner pid", p.pid)
