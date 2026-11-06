#!/usr/bin/env python3
"""D63 L1/L2 second Lean lane (2026-11-06): run one command under the zk60 resource guard, detached
(macOS has no setsid / flock; `start_new_session` survives the session).

usage: run_guarded.py <label> <class> <need_gib> <cap_gib> -- <cmd...>

Writes `<label>.log` (the command's output, through the guard's --log), `<label>.done` (its exit
code, the guard's --done) and `<label>.guard.json` in this directory. The guard label is
`lean-l2c-<label>` (the third lane, 2026-11-06; the second lane used `lean-l2b-`).
"""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
GUARD = "/Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py"


def main():
    label, klass, need, cap = sys.argv[1:5]
    assert sys.argv[5] == "--"
    cmd = sys.argv[6:]
    done = os.path.join(HERE, f"{label}.done")
    if os.path.exists(done):
        os.remove(done)
    guard = [sys.executable, GUARD, "run", "--class", klass, "--need-gib", need, "--cap-gib", cap,
             "--wait-secs", "14400", "--label", f"lean-l2c-{label}",
             "--log", os.path.join(HERE, f"{label}.log"), "--done", done,
             "--result-json", os.path.join(HERE, f"{label}.guard.json"), "--", *cmd]
    out = open(os.path.join(HERE, f"{label}.runner.out"), "w")
    p = subprocess.Popen(guard, start_new_session=True, stdin=subprocess.DEVNULL, stdout=out,
                         stderr=subprocess.STDOUT)
    print("detached guard pid", p.pid)


if __name__ == "__main__":
    main()
