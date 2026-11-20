#!/usr/bin/env python3
"""A35: run one leaf command through the resource guard, from this worktree (A33's guarded.py, unchanged in behaviour).

usage: guarded.py <label> <class build|cpu|gpu> <need_gib> <cap_gib> <max_secs> [ENV=VAL ...] -- <leaf command ...>

Writes raw/<label>.log (the leaf's stdout+stderr), raw/<label>.guard.json (the guard's terminal record, with its
run id) and raw/<label>.status_pre.txt (the guard's `status` and `pgrep -fl ds4-bench` just before the launch, and
`pgrep` after). Default guard poll (5 s), python3 -B, --wait-secs 21600 (the guard waits for the heavy lock).
Exits with the guard's exit code.
"""
import os
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
RAW = HERE / "raw"
GUARD = "/Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py"


def main() -> int:
    argv = sys.argv[1:]
    sep = argv.index("--")
    head, leaf = argv[:sep], argv[sep + 1:]
    label, cls, need, cap, max_secs, *envs = head
    RAW.mkdir(exist_ok=True)
    if Path("/tmp/HOLD").exists():
        print("ABORT: /tmp/HOLD exists")
        return 99
    env = os.environ.copy()
    env.pop("ZK60_GUARD_POLL_SECS", None)
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    for e in envs:
        k, _, v = e.partition("=")
        env[k] = v
    st = subprocess.run([sys.executable, "-B", GUARD, "status"], capture_output=True, text=True).stdout
    ds4 = subprocess.run(["pgrep", "-fl", "ds4-bench"], capture_output=True, text=True).stdout
    (RAW / f"{label}.status_pre.txt").write_text(f"{time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}\n--- guard status ---\n{st}--- pgrep -fl ds4-bench ---\n{ds4 or '(none)'}\n")
    log = RAW / f"{label}.log"
    gj = RAW / f"{label}.guard.json"
    done = RAW / f"{label}.done"
    for p in (log, gj, done):
        p.unlink(missing_ok=True)
    cmd = [sys.executable, "-B", GUARD, "run", "--class", cls, "--label", f"a35-{label}", "--need-gib", need, "--cap-gib", cap,
           "--max-secs", max_secs, "--wait-secs", "21600", "--log", str(log), "--done", str(done), "--result-json", str(gj), "--", *leaf]
    print(f"[{time.strftime('%H:%M:%S')}] launching {label}", flush=True)
    cp = subprocess.run(cmd, env=env, stdin=subprocess.DEVNULL)
    ds4_after = subprocess.run(["pgrep", "-fl", "ds4-bench"], capture_output=True, text=True).stdout
    with (RAW / f"{label}.status_pre.txt").open("a") as f:
        f.write(f"--- {time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())} pgrep -fl ds4-bench after the run ---\n{ds4_after or '(none)'}\n")
    print(f"[{time.strftime('%H:%M:%S')}] {label} guard exit {cp.returncode}", flush=True)
    return cp.returncode


if __name__ == "__main__":
    sys.exit(main())
