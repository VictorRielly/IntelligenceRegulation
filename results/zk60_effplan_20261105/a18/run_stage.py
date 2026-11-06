#!/usr/bin/env python3
"""A18 (efficiency plan, 2026-11-05): run stage scripts under the resource guard, one
after another, detached (macOS has no setsid / flock; start_new_session survives the
session). A17's runner with A18's labels and a per-stage memory need.

usage: run_stage.py [--need G] [--cap G] <stage> [<stage> ...]   (parent: re-spawns detached, prints the PID)
       run_stage.py --child G C <stage> [<stage> ...]             (the runner)

Each <stage> names `<stage>.sh` in this directory. The guard runs each as ONE job of
class gpu (`--need-gib G --cap-gib C --wait-secs 14400`; defaults 64 / 140), logging to
`<stage>.guard.log`, its terminal record in `<stage>.guard.json`, its exit code in
`<stage>.done` (the guard's `--done`). The scripts write their own progress lines to
`<stage>.progress`. A later stage starts only after the earlier one's guard has ended.
"""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
GUARD = "/Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py"


def run(stage, need, cap):
    script = os.path.join(HERE, f"{stage}.sh")
    done = os.path.join(HERE, f"{stage}.done")
    if os.path.exists(done):
        os.remove(done)
    cmd = [sys.executable, GUARD, "run", "--class", "gpu", "--need-gib", need, "--cap-gib", cap,
           "--wait-secs", "14400", "--label", f"a18-{stage}",
           "--log", os.path.join(HERE, f"{stage}.guard.log"),
           "--done", done,
           "--result-json", os.path.join(HERE, f"{stage}.guard.json"),
           "--", "/bin/bash", script]
    p = subprocess.run(cmd, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if not os.path.exists(done):
        with open(done, "w") as f:
            f.write(f"{p.returncode}\n")


if __name__ == "__main__":
    if sys.argv[1] == "--child":
        need, cap = sys.argv[2], sys.argv[3]
        for stage in sys.argv[4:]:
            run(stage, need, cap)
    else:
        args = sys.argv[1:]
        need, cap = "64", "140"
        while args and args[0].startswith("--"):
            if args[0] == "--need":
                need = args[1]
            elif args[0] == "--cap":
                cap = args[1]
            args = args[2:]
        out = open(os.path.join(HERE, f"{args[0]}.runner.out"), "w")
        p = subprocess.Popen([sys.executable, os.path.abspath(__file__), "--child", need, cap, *args],
                             start_new_session=True, stdin=subprocess.DEVNULL, stdout=out, stderr=subprocess.STDOUT)
        print("detached runner pid", p.pid)
