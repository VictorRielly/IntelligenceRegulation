#!/usr/bin/env python3
"""L2 (research tick 24): A13's window on the prover-paced stream, one guarded GPU job.

usage: run_l2.py <label> <arms> [max secs, default 1500]
       e.g. run_l2.py run1 serve4,serve4+ahead8,serve4+ahead16,serve4+ahead32

The leaf and its environment are Batch 7's and A33's (results/zk60_a33_seal_dedup_20261117/ab_run.py), with two
differences: several arms in ONE process (HL_A22_AB=<arms>) and HL_D55_AB_ALTERNATE=1 (the arm order is reversed in
odd passes). The binary is A33's merged patched test binary; its SHA-256 is checked against the value recorded on
2026-11-17 before the launch. Writes raw/<label>.log, raw/<label>.guard.json, raw/<label>.done (the leaf's exit code)
and raw/<label>.status_pre.txt (the guard's status, the load average and pgrep -fl ds4-bench before and after).
Exits with the guard's exit code. Nothing here changes a source file.
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
BIN = ROOT / ".claude/worktrees/agent-a4d782b46866ea303/ops/zkp-mvp/gpu-metal/hashline/target/release/deps/hashline-4ff65cafe9d88959"
BIN_SHA = "c54517e2514d4498b4c9cb0471309a178058ba411ddec1a38cf834002c4f8913"
TEST = "private_block::run::fork::tests::a22::a22_stream_ab"
ENV = {
    "HL_GPU": "1", "HL_GPU_REQUIRED": "1", "HL_PB_ORACLE": "0", "HL_METAL_TIMING": "0",
    "HL_D55_PROFILE": "W16R2_8B_T128_H24", "HL_D55_L": "32", "HL_D55_WORKERS": "6", "HL_A19_BUDGET_GIB": "32",
    "HL_A22_AB_PASSES": "6", "HL_D55_AB_ALTERNATE": "1",
}
NEED_GIB, CAP_GIB, MAX_SECS = "80", "110", "1500"


def sha(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as f:
        for c in iter(lambda: f.read(1 << 20), b""):
            h.update(c)
    return h.hexdigest()


def out(cmd):
    return subprocess.run(cmd, capture_output=True, text=True).stdout


def main() -> int:
    label, arms = sys.argv[1], sys.argv[2]
    max_secs = sys.argv[3] if len(sys.argv) > 3 else MAX_SECS
    RAW.mkdir(exist_ok=True)
    if Path("/tmp/HOLD").exists():
        print("ABORT: /tmp/HOLD exists")
        return 99
    got = sha(BIN)
    if got != BIN_SHA:
        print(f"ABORT: the binary's hash differs: {got}")
        return 98
    env = os.environ.copy()
    env.pop("ZK60_GUARD_POLL_SECS", None)
    env.pop("HL_D55_AHEAD", None)
    env.pop("HL_A27_GPU_TRACE", None)
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
    cmd = [sys.executable, "-B", GUARD, "run", "--class", "gpu", "--label", f"l2-ahead-{label}", "--need-gib", NEED_GIB,
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
