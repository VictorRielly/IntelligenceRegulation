#!/usr/bin/env python3
"""A21 (efficiency plan, 2026-11-06): run stage scripts under the resource guard, one
after another, detached (macOS has no setsid / flock; start_new_session survives the
session). A20's runner with A21's labels.

usage: run_stage.py [--class C] [--need G] [--cap G] <stage> [<stage> ...]   (parent: re-spawns detached)
       run_stage.py --child C G CAP <stage> [<stage> ...]                    (the runner)

Each <stage> names `<stage>.sh` in this directory. The guard runs each as ONE job of
class C (default gpu; `build` for compile-only stages) with `--need-gib G --cap-gib CAP
--wait-secs 14400` (defaults 64 / 140), logging to `<stage>.guard.log`, its terminal
record in `<stage>.guard.json`, its exit code in `<stage>.done` (the guard's `--done`).
The scripts write their own progress lines to `<stage>.progress`. A later stage starts
only after the earlier one's guard has ended.
"""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
GUARD = "/Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py"


def run(stage, klass, need, cap):
    script = os.path.join(HERE, f"{stage}.sh")
    done = os.path.join(HERE, f"{stage}.done")
    if os.path.exists(done):
        os.remove(done)
    cmd = [sys.executable, GUARD, "run", "--class", klass, "--need-gib", need, "--cap-gib", cap,
           "--wait-secs", "14400", "--label", f"a21-{stage}",
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
        klass, need, cap = sys.argv[2], sys.argv[3], sys.argv[4]
        for stage in sys.argv[5:]:
            run(stage, klass, need, cap)
    else:
        args = sys.argv[1:]
        klass, need, cap = "gpu", "64", "140"
        while args and args[0].startswith("--"):
            if args[0] == "--class":
                klass = args[1]
            elif args[0] == "--need":
                need = args[1]
            elif args[0] == "--cap":
                cap = args[1]
            args = args[2:]
        out = open(os.path.join(HERE, f"{args[0]}.runner.out"), "w")
        p = subprocess.Popen([sys.executable, os.path.abspath(__file__), "--child", klass, need, cap, *args],
                             start_new_session=True, stdin=subprocess.DEVNULL, stdout=out, stderr=subprocess.STDOUT)
        print("detached runner pid", p.pid)
