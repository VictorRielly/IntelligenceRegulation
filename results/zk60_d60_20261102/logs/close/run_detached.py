#!/usr/bin/env python3
"""D60 review closure (2026-11-02): the detached runner (the Mac's no-hangup recipe: python3, start_new_session).

Usage: python3 run_detached.py <name> -- <cmd...>
Runs <cmd> detached in its own session; its output goes to logs/close/<name>.out and its exit code to
logs/close/<name>.done (written last). The heavy steps inside <cmd> go through the shared resource guard.
The parent prints the child's pid and exits."""
import os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))


def main():
    if "--child" in sys.argv:
        i = sys.argv.index("--child")
        name, cmd = sys.argv[i + 1], sys.argv[i + 2:]
        done = os.path.join(HERE, f"{name}.done")
        if os.path.exists(done):
            os.remove(done)
        with open(os.path.join(HERE, f"{name}.out"), "w") as out:
            rc = subprocess.run(cmd, stdout=out, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL).returncode
        with open(done + ".partial", "w") as f:
            f.write(f"{rc}\n")
        os.replace(done + ".partial", done)
        return
    if len(sys.argv) < 4 or sys.argv[2] != "--":
        raise SystemExit(__doc__)
    name, cmd = sys.argv[1], sys.argv[3:]
    p = subprocess.Popen([sys.executable, os.path.abspath(__file__), "--child", name, *cmd], start_new_session=True,
                         stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    print(f"detached {name} pid {p.pid}")


if __name__ == "__main__":
    main()
