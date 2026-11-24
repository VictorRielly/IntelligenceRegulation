#!/usr/bin/env python3
"""6-pass alternating 8B stream A/B runner for agy/host-wave2 (q1 vs q0; hw1+ad0 / hw1+ad1 vs hw0)."""
import hashlib
import os
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
RAW = HERE / "raw"
ROOT = Path("/Users/victorrielly/IntelligenceRegulation")
WT = ROOT / ".agy-worktrees/host-wave2"
GUARD = str(ROOT / "scripts/zk60_resource_guard.py")
BIN = WT / "ops/zkp-mvp/gpu-metal/hashline/target/release/deps/hashline-5d23267366f4fc6a"
BIN_SHA = "864d96525955541eda6e0af7e808d12c3bd2b0280101e4c1f6c2444affd12971"
TEST = "private_block::run::fork::tests::a22::a22_stream_ab"
ENV = {
    "HL_GPU": "1",
    "HL_GPU_REQUIRED": "1",
    "HL_PB_ORACLE": "0",
    "HL_METAL_TIMING": "0",
    "HL_D55_PROFILE": "W16R2_8B_T128_H24",
    "HL_D55_L": "32",
    "HL_D55_WORKERS": "6",
    "HL_A19_BUDGET_GIB": "32",
    "HL_D55_AB_ALTERNATE": "1",
}
STRIP = (
    "ZK60_GUARD_POLL_SECS",
    "HL_D55_AHEAD",
    "HL_A27_GPU_TRACE",
    "HL_A35_BOUNDS_AHEAD",
    "HL_METAL_FUSED_RS",
    "HL_METAL_SPARSE_FOLD",
    "HL_METAL_SPARSE_FOLD_REG8",
    "HL_METAL_SC_CHAIN_FAST",
    "HL_HOST_FAST",
    "HL_HOST_FAST_W2",
    "HL_HOST_FAST_ASYNC_DROP",
    "HL_CLASSIFY_HOST_FAST",
    "HL_METAL_OPEN_FAST",
    "HL_METAL_OPEN_SKIP_TABLES",
    "HL_METAL_OPEN_HOST_GATHER",
    "HL_METAL_BATCH",
    "HL_METAL_BATCH_TAIL_US",
    "HL_METAL_TAIL_BUDGET_US",
    "HL_METAL_QUEUES",
    "HL_METAL_SPIN_US",
    "HL_A36_CORE_AHEAD",
)


def sha(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as f:
        for c in iter(lambda: f.read(1 << 20), b""):
            h.update(c)
    return h.hexdigest()


def out(cmd):
    return subprocess.run(cmd, capture_output=True, text=True).stdout


def main() -> int:
    label = sys.argv[1]
    arms = sys.argv[2]
    passes = sys.argv[3] if len(sys.argv) > 3 else "6"
    max_secs = sys.argv[4] if len(sys.argv) > 4 else "1800"
    RAW.mkdir(parents=True, exist_ok=True)
    if Path("/tmp/HOLD").exists():
        print("ABORT: /tmp/HOLD exists")
        return 99
    if subprocess.run(["pgrep", "-f", "[d]s4-bench"], capture_output=True).returncode == 0:
        print("ABORT: ds4-bench is running")
        return 97
    got = sha(BIN)
    if got != BIN_SHA:
        print(f"ABORT: binary SHA mismatch: {got}")
        return 98
    env = os.environ.copy()
    for k in STRIP:
        env.pop(k, None)
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    env.update(ENV)
    env["HL_A22_AB"] = arms
    env["HL_A22_AB_PASSES"] = passes
    pre = RAW / f"{label}.status_pre.txt"
    pre.write_text(
        f"{time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}\nbinary {BIN} sha256 {got}\narms {arms}\npasses {passes}\n"
        f"env {ENV}\n--- guard status ---\n{out([sys.executable, '-B', GUARD, 'status'])}"
        f"--- sysctl -n vm.loadavg ---\n{out(['sysctl', '-n', 'vm.loadavg'])}"
        f"--- pgrep -fl ds4-bench ---\n{out(['pgrep', '-fl', 'ds4-bench']) or '(none)'}\n"
    )
    log, gj, done = RAW / f"{label}.log", RAW / f"{label}.guard.json", RAW / f"{label}.done"
    for p in (log, gj, done):
        p.unlink(missing_ok=True)
    cmd = [
        sys.executable, "-B", GUARD, "run",
        "--class", "gpu", "--label", f"agy-host-wave2-8b-{label}",
        "--need-gib", "80", "--cap-gib", "110",
        "--max-secs", max_secs, "--wait-secs", "3600",
        "--log", str(log), "--done", str(done), "--result-json", str(gj),
        "--", str(BIN), "--ignored", "--exact", "--nocapture", TEST,
    ]
    print(f"[{time.strftime('%H:%M:%S')}] launching {label}: {arms} ({passes} passes)", flush=True)
    cp = subprocess.run(cmd, env=env, stdin=subprocess.DEVNULL)
    with pre.open("a") as f:
        f.write(
            f"--- after the run, {time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())} ---\n"
            f"loadavg {out(['sysctl', '-n', 'vm.loadavg'])}"
            f"ds4-bench {out(['pgrep', '-fl', 'ds4-bench']) or '(none)'}\n"
        )
    print(f"[{time.strftime('%H:%M:%S')}] {label} guard exit {cp.returncode}", flush=True)
    return cp.returncode


if __name__ == "__main__":
    sys.exit(main())
