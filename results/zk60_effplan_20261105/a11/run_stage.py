#!/usr/bin/env python3
"""A11 (efficiency plan, 2026-11-05): run stage scripts under the resource guard, one
after another, detached (macOS has no setsid / flock; start_new_session survives the
session). A7's runner with A11's labels.

usage: run_stage.py <stage> [<stage> ...]            (parent: re-spawns detached, prints the PID)
       run_stage.py --child <stage> [<stage> ...]    (the runner)

Each <stage> names `<stage>.sh` in this directory. The guard runs each as ONE job of
class gpu (`--need-gib 64 --cap-gib 140 --wait-secs 7200`), logging to
`<stage>.guard.log`, its terminal record in `<stage>.guard.json`; the runner writes the
exit code to `<stage>.done`. The scripts write their own progress lines to
`<stage>.progress`. A later stage starts only after the earlier one's guard has ended.
"""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
GUARD = "/Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py"


def run(stage):
    script = os.path.join(HERE, f"{stage}.sh")
    done = os.path.join(HERE, f"{stage}.done")
    if os.path.exists(done):
        os.remove(done)
    cmd = [sys.executable, GUARD, "run", "--class", "gpu", "--need-gib", "64", "--cap-gib", "140",
           "--wait-secs", "7200", "--label", f"a11-{stage}",
           "--log", os.path.join(HERE, f"{stage}.guard.log"),
           "--result-json", os.path.join(HERE, f"{stage}.guard.json"),
           "--", "/bin/bash", script]
    p = subprocess.run(cmd, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    with open(done, "w") as f:
        f.write(f"{p.returncode}\n")


if __name__ == "__main__":
    if sys.argv[1] == "--child":
        for stage in sys.argv[2:]:
            run(stage)
    else:
        stages = sys.argv[1:]
        out = open(os.path.join(HERE, f"{stages[0]}.runner.out"), "w")
        p = subprocess.Popen([sys.executable, os.path.abspath(__file__), "--child", *stages], start_new_session=True,
                             stdin=subprocess.DEVNULL, stdout=out, stderr=subprocess.STDOUT)
        print("detached runner pid", p.pid)
