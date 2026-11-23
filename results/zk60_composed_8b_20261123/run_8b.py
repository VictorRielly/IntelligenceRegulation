#!/usr/bin/env python3
"""The composed device bundle (fused RS encoder + sparse opening fold) on the synthetic 8B stream, merged head.

usage: run_8b.py [--detached] <label> <arms> [passes, default 6] [max secs, default 2400]
       e.g. run_8b.py set1 serve8+lanes2,serve8+lanes2+frs1+sf1,serve9+lanes3,serve9+lanes3+frs1+sf1

One guarded GPU job. The leaf and environment are those of results/zk60_a35_replication_20261120/run_rep.py (test
a22_stream_ab, several arms in one process, arm order reversed in odd passes). The binary is the lib test binary the
merge gate built in the main checkout from the merged tree (source head fe68a2f9); its SHA-256 is checked before the run.
Since f323bb82 an arm with no ba word runs with the A35 commit-ahead switch on.
With "--detached" first, the runner re-starts itself in a new session and waits for it.
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
BIN = ROOT / "ops/zkp-mvp/gpu-metal/hashline/target/release/deps/hashline-a90b6cf7715dc2a7"
BIN_SHA = "30ba5501928f888d308c8ebc5549ea62f4c55f8c4290fbede1819258a6cc59fb"
TEST = "private_block::run::fork::tests::a22::a22_stream_ab"
ENV = {
    "HL_GPU": "1", "HL_GPU_REQUIRED": "1", "HL_PB_ORACLE": "0", "HL_METAL_TIMING": "0",
    "HL_D55_PROFILE": "W16R2_8B_T128_H24", "HL_D55_L": "32", "HL_D55_WORKERS": "6", "HL_A19_BUDGET_GIB": "32",
    "HL_D55_AB_ALTERNATE": "1",
}
# switches an arm word must set, never the caller's shell
STRIP = ("ZK60_GUARD_POLL_SECS", "HL_D55_AHEAD", "HL_A27_GPU_TRACE", "HL_A35_BOUNDS_AHEAD", "HL_METAL_FUSED_RS",
         "HL_METAL_SPARSE_FOLD", "HL_METAL_OPEN_FAST", "HL_METAL_BATCH_TAIL_US", "HL_METAL_TAIL_BUDGET_US",
         "HL_METAL_QUEUES", "HL_METAL_SPIN_US", "HL_A36_CORE_AHEAD")
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
    passes = argv[2] if len(argv) > 2 else "6"
    max_secs = argv[3] if len(argv) > 3 else "2400"
    if Path("/tmp/HOLD").exists():
        print("ABORT: /tmp/HOLD exists")
        return 99
    got = sha(BIN)
    if got != BIN_SHA:
        print(f"ABORT: the binary's hash differs: {got}")
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
        f"--- pgrep -fl ds4-bench ---\n{out(['pgrep', '-fl', 'ds4-bench']) or '(none)'}\n")
    log, gj, done = RAW / f"{label}.log", RAW / f"{label}.guard.json", RAW / f"{label}.done"
    for p in (log, gj, done):
        p.unlink(missing_ok=True)
    cmd = [sys.executable, "-B", GUARD, "run", "--class", "gpu", "--label", f"composed8b-{label}", "--need-gib", NEED_GIB,
           "--cap-gib", CAP_GIB, "--max-secs", max_secs, "--wait-secs", "3600", "--log", str(log), "--done", str(done),
           "--result-json", str(gj), "--", str(BIN), "--ignored", "--exact", "--nocapture", TEST]
    print(f"[{time.strftime('%H:%M:%S')}] launching {label}: {arms} ({passes} passes)", flush=True)
    cp = subprocess.run(cmd, env=env, stdin=subprocess.DEVNULL)
    with pre.open("a") as f:
        f.write(f"--- after the run, {time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())} ---\n"
                f"loadavg {out(['sysctl', '-n', 'vm.loadavg'])}ds4-bench {out(['pgrep', '-fl', 'ds4-bench']) or '(none)'}\n")
    print(f"[{time.strftime('%H:%M:%S')}] {label} guard exit {cp.returncode}", flush=True)
    return cp.returncode


if __name__ == "__main__":
    sys.exit(main())
