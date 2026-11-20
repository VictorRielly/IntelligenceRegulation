#!/usr/bin/env python3
"""A35 stage 4: the one guarded GPU timing job (copied from results/zk60_l2_ahead_window_20261120/run_l2.py, adapted).

usage: run_a35.py <label> [--detach]

The leaf and its environment are run_l2.py's (Batch 7's and A33's): one process, both arms in it
(HL_A22_AB=serve8+lanes2,serve8+lanes2+ba1), HL_A22_AB_PASSES=6, HL_D55_AB_ALTERNATE=1, the guard's class gpu,
--need-gib 80 --cap-gib 110. Differences from run_l2.py: the binary is this worktree's A35 test binary (its path from
raw/g1_build.log, its SHA-256 recorded before and checked after), HL_A35_BOUNDS_AHEAD is removed from the
environment (the arm word sets it), and the label prefix. HL_D55_AHEAD and HL_A27_GPU_TRACE are removed as in run_l2.py.
Writes raw/<label>.log, .guard.json, .done (the leaf's exit code), .status_pre.txt (the guard's status, the load
average and pgrep -fl ds4-bench before and after). Refuses to start when ds4-bench runs or another guarded job is
listed. --detach: run in its own session, output to raw/<label>.runner.txt, return at once.
"""
import hashlib
import os
import re
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
RAW = HERE / "raw"
GUARD = "/Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py"
W = HERE.parent.parent / "ops/zkp-mvp/gpu-metal/hashline"
TEST = "private_block::run::fork::tests::a22::a22_stream_ab"
ARMS = "serve8+lanes2,serve8+lanes2+ba1"
ENV = {
    "HL_GPU": "1", "HL_GPU_REQUIRED": "1", "HL_PB_ORACLE": "0", "HL_METAL_TIMING": "0",
    "HL_D55_PROFILE": "W16R2_8B_T128_H24", "HL_D55_L": "32", "HL_D55_WORKERS": "6", "HL_A19_BUDGET_GIB": "32",
    "HL_A22_AB_PASSES": "6", "HL_D55_AB_ALTERNATE": "1",
}
NEED_GIB, CAP_GIB, MAX_SECS = "80", "110", "1800"


def sha(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as f:
        for c in iter(lambda: f.read(1 << 20), b""):
            h.update(c)
    return h.hexdigest()


def out(cmd):
    return subprocess.run(cmd, capture_output=True, text=True).stdout


def binary() -> Path:
    m = re.findall(r"Executable unittests src/lib\.rs \(([^)]+)\)", (RAW / "g1_build.log").read_text(errors="replace"))
    p = Path(m[-1])
    return p if p.is_absolute() else HERE.parent.parent / p


def main() -> int:
    label = sys.argv[1]
    if "--detach" in sys.argv[2:]:
        RAW.mkdir(exist_ok=True)
        with (RAW / f"{label}.runner.txt").open("w") as f:
            subprocess.Popen([sys.executable, "-B", str(Path(__file__).resolve()), label], stdin=subprocess.DEVNULL, stdout=f, stderr=subprocess.STDOUT, start_new_session=True)
        print(f"detached {label}")
        return 0
    if Path("/tmp/HOLD").exists():
        print("ABORT: /tmp/HOLD exists")
        return 99
    status = out([sys.executable, "-B", GUARD, "status"])
    ds4 = out(["pgrep", "-fl", "ds4-bench"])
    b = binary()
    got = sha(b)
    pre = RAW / f"{label}.status_pre.txt"
    pre.write_text(
        f"{time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}\nbinary {b.name} sha256 {got}\narms {ARMS}\nenv {ENV}\n"
        f"--- guard status ---\n{status}"
        f"--- sysctl -n vm.loadavg ---\n{out(['sysctl', '-n', 'vm.loadavg'])}"
        f"--- pgrep -fl ds4-bench ---\n{ds4 or '(none)'}\n")
    if ds4.strip():
        print("ABORT: ds4-bench is running")
        return 97
    if re.search(r"^\s+job\s", status, re.M):
        print("ABORT: another guarded job is listed in the guard's status")
        return 96
    env = os.environ.copy()
    for k in ("ZK60_GUARD_POLL_SECS", "HL_D55_AHEAD", "HL_A27_GPU_TRACE", "HL_A35_BOUNDS_AHEAD"):
        env.pop(k, None)
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    env.update(ENV)
    env["HL_A22_AB"] = ARMS
    log, gj, done = RAW / f"{label}.log", RAW / f"{label}.guard.json", RAW / f"{label}.done"
    for p in (log, gj, done):
        p.unlink(missing_ok=True)
    cmd = [sys.executable, "-B", GUARD, "run", "--class", "gpu", "--label", f"a35-{label}", "--need-gib", NEED_GIB,
           "--cap-gib", CAP_GIB, "--max-secs", MAX_SECS, "--wait-secs", "3600", "--log", str(log), "--done", str(done),
           "--result-json", str(gj), "--", str(b), "--ignored", "--exact", "--nocapture", TEST]
    print(f"[{time.strftime('%H:%M:%S')}] launching {label}: {ARMS}", flush=True)
    cp = subprocess.run(cmd, env=env, stdin=subprocess.DEVNULL)
    after = sha(b)
    with pre.open("a") as f:
        f.write(f"--- after the run, {time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())} ---\n"
                f"binary sha256 {after} ({'unchanged' if after == got else 'CHANGED'})\n"
                f"loadavg {out(['sysctl', '-n', 'vm.loadavg'])}ds4-bench {out(['pgrep', '-fl', 'ds4-bench']) or '(none)'}\n")
    print(f"[{time.strftime('%H:%M:%S')}] {label} guard exit {cp.returncode}", flush=True)
    return cp.returncode


if __name__ == "__main__":
    sys.exit(main())
