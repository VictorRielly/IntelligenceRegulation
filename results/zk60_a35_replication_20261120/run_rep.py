#!/usr/bin/env python3
"""A35 replication by the coordinator: the A35 branch's test binary, one guarded GPU job, started in its own session.

usage: run_rep.py <label> <arms> [max secs, default 2400]
       e.g. run_rep.py rep1 serve8+lanes2,serve8+lanes2+ba1,serve9+lanes3,serve9+lanes3+ba1

The leaf and environment are those of results/zk60_l2_ahead_window_20261120/run_l2.py (Batch 7's and A33's, several arms
in one process, arm order reversed in odd passes). The binary is the one the A35 agent built from its branch head
b0b5cf27 and timed (guard run 5dee3dc2932b); its SHA-256 is checked against the value its run recorded.
With the argument "--detached" first, the runner re-starts itself in a new session and waits for it.
Writes raw/<label>.log, .guard.json, .done, .status_pre.txt (and .runner.txt when detached). No source file changes.
"""
import hashlib
import os
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
RAW = HERE / "raw"
ROOT = Path("/Users/victorrielly/IntelligenceRegulation")
GUARD = str(ROOT / "scripts/zk60_resource_guard.py")
BIN = ROOT / ".claude/worktrees/agent-addfd11fa51fe5d25/ops/zkp-mvp/gpu-metal/hashline/target/release/deps/hashline-ee9e07880f531987"
BIN_SHA = "092590a2988938786193a27e29ce0caff128484666452e9fc74b77bf900da644"
TEST = "private_block::run::fork::tests::a22::a22_stream_ab"
ENV = {
    "HL_GPU": "1", "HL_GPU_REQUIRED": "1", "HL_PB_ORACLE": "0", "HL_METAL_TIMING": "0",
    "HL_D55_PROFILE": "W16R2_8B_T128_H24", "HL_D55_L": "32", "HL_D55_WORKERS": "6", "HL_A19_BUDGET_GIB": "32",
    "HL_A22_AB_PASSES": "6", "HL_D55_AB_ALTERNATE": "1",
}
NEED_GIB, CAP_GIB = "80", "110"


def sha(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as f:
        for c in iter(lambda: f.read(1 << 20), b""):
            h.update(c)
    return h.hexdigest()


def out(cmd):
    return subprocess.run(cmd, capture_output=True, text=True).stdout


def main() -> int:
    argv = sys.argv[1:]
    RAW.mkdir(exist_ok=True)
    if argv and argv[0] == "--detached":
        label = argv[1]
        with (RAW / f"{label}.runner.txt").open("w") as f:
            p = subprocess.Popen([sys.executable, "-B", str(Path(__file__).resolve()), *argv[1:]], stdin=subprocess.DEVNULL,
                                 stdout=f, stderr=subprocess.STDOUT, start_new_session=True)
        rc = p.wait()
        print(f"{label}: runner exit {rc}")
        gj = RAW / f"{label}.guard.json"
        if gj.exists():
            print(gj.read_text()[:1200])
        return rc
    label, arms = argv[0], argv[1]
    max_secs = argv[2] if len(argv) > 2 else "2400"
    if Path("/tmp/HOLD").exists():
        print("ABORT: /tmp/HOLD exists")
        return 99
    got = sha(BIN)
    if got != BIN_SHA:
        print(f"ABORT: the binary's hash differs: {got}")
        return 98
    env = os.environ.copy()
    for k in ("ZK60_GUARD_POLL_SECS", "HL_D55_AHEAD", "HL_A27_GPU_TRACE", "HL_A35_BOUNDS_AHEAD"):
        env.pop(k, None)
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    env.update(ENV)
    env["HL_A22_AB"] = arms
    pre = RAW / f"{label}.status_pre.txt"
    pre.write_text(
        f"{time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}\nbinary {BIN} sha256 {got}\narms {arms}\nenv {ENV}\n"
        f"--- guard status ---\n{out([sys.executable, '-B', GUARD, 'status'])}"
        f"--- sysctl -n vm.loadavg ---\n{out(['sysctl', '-n', 'vm.loadavg'])}"
        f"--- pgrep -fl ds4-bench ---\n{out(['pgrep', '-fl', 'ds4-bench']) or '(none)'}\n")
    log, gj, done = RAW / f"{label}.log", RAW / f"{label}.guard.json", RAW / f"{label}.done"
    for p in (log, gj, done):
        p.unlink(missing_ok=True)
    cmd = [sys.executable, "-B", GUARD, "run", "--class", "gpu", "--label", f"a35-rep-{label}", "--need-gib", NEED_GIB,
           "--cap-gib", CAP_GIB, "--max-secs", max_secs, "--wait-secs", "3600", "--log", str(log), "--done", str(done),
           "--result-json", str(gj), "--", str(BIN), "--ignored", "--exact", "--nocapture", TEST]
    print(f"[{time.strftime('%H:%M:%S')}] launching {label}: {arms}", flush=True)
    cp = subprocess.run(cmd, env=env, stdin=subprocess.DEVNULL)
    with pre.open("a") as f:
        f.write(f"--- after the run, {time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())} ---\n"
                f"loadavg {out(['sysctl', '-n', 'vm.loadavg'])}ds4-bench {out(['pgrep', '-fl', 'ds4-bench']) or '(none)'}\n")
    print(f"[{time.strftime('%H:%M:%S')}] {label} guard exit {cp.returncode}", flush=True)
    return cp.returncode


if __name__ == "__main__":
    sys.exit(main())
