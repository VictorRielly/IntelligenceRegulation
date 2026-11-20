#!/usr/bin/env python3
"""Start run_l2.py in its own session (it survives the launching session) and wait for it.

usage: launch_detached.py <label> <arms>
The runner's own output goes to raw/<label>.runner.txt. Prints the exit code and the guard's terminal record.
"""
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent


def main() -> int:
    label, arms = sys.argv[1], sys.argv[2]
    (HERE / "raw").mkdir(exist_ok=True)
    with (HERE / "raw" / f"{label}.runner.txt").open("w") as f:
        p = subprocess.Popen([sys.executable, "-B", str(HERE / "run_l2.py"), label, arms, *sys.argv[3:4]], stdin=subprocess.DEVNULL,
                             stdout=f, stderr=subprocess.STDOUT, start_new_session=True)
    rc = p.wait()
    print(f"{label}: runner exit {rc}")
    gj = HERE / "raw" / f"{label}.guard.json"
    if gj.exists():
        print(gj.read_text()[:1500])
    return rc


if __name__ == "__main__":
    sys.exit(main())
