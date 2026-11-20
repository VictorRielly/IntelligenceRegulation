#!/usr/bin/env python3
"""The harness stream at the installed Shieldstral profile (W16R2_SHIELD_T128_H24, 26 layers), with an 8B control.

usage: python3 -B run_stream.py            start the whole sequence in its own session and wait for it
       python3 -B run_stream.py --inner    (used by the line above) run the jobs one after the other

The leaf, the binary and the environment are those of results/zk60_a35_replication_20261120/run_rep.py (the A35
branch's test binary, test a22_stream_ab, several arms in one process, arm order reversed in odd passes, no GPU
trace). Only HL_D55_PROFILE, HL_D55_L and the number of passes differ per job. One guarded GPU-class leaf per job,
one after the other. Writes raw/<label>.log, .guard.json, .done, .status_pre.txt, raw/run.log and raw/run.done.
Refuses to start if raw/run.done exists. No source file changes.
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
BASE_ENV = {
    "HL_GPU": "1", "HL_GPU_REQUIRED": "1", "HL_PB_ORACLE": "0", "HL_METAL_TIMING": "0",
    "HL_D55_WORKERS": "6", "HL_A19_BUDGET_GIB": "32", "HL_D55_AB_ALTERNATE": "1",
}
ARMS = "serve8+lanes2,serve8+lanes2+ba1"
# label, profile, layers, passes
JOBS = [
    ("shield26", "W16R2_SHIELD_T128_H24", "26", "6"),
    ("ctl8b32", "W16R2_8B_T128_H24", "32", "3"),
]
NEED_GIB, CAP_GIB, MAX_SECS = "80", "110", "2400"


def sha(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as f:
        for c in iter(lambda: f.read(1 << 20), b""):
            h.update(c)
    return h.hexdigest()


def out(cmd):
    return subprocess.run(cmd, capture_output=True, text=True).stdout


def say(msg):
    line = f"[{time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}] {msg}"
    print(line, flush=True)
    with (RAW / "run.log").open("a") as f:
        f.write(line + "\n")


def one(label, profile, layers, passes) -> int:
    got = sha(BIN)
    if got != BIN_SHA:
        say(f"ABORT {label}: the binary's hash differs: {got}")
        return 98
    env = os.environ.copy()
    for k in ("ZK60_GUARD_POLL_SECS", "HL_D55_AHEAD", "HL_A27_GPU_TRACE", "HL_A35_BOUNDS_AHEAD"):
        env.pop(k, None)
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    job_env = dict(BASE_ENV, HL_D55_PROFILE=profile, HL_D55_L=layers, HL_A22_AB_PASSES=passes, HL_A22_AB=ARMS)
    env.update(job_env)
    pre = RAW / f"{label}.status_pre.txt"
    pre.write_text(
        f"{time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}\nbinary {BIN} sha256 {got}\nenv {job_env}\n"
        f"--- guard status ---\n{out([sys.executable, '-B', GUARD, 'status'])}"
        f"--- sysctl -n vm.loadavg ---\n{out(['sysctl', '-n', 'vm.loadavg'])}"
        f"--- pgrep -fl ds4-bench ---\n{out(['pgrep', '-fl', 'ds4-bench']) or '(none)'}\n")
    log, gj, done = RAW / f"{label}.log", RAW / f"{label}.guard.json", RAW / f"{label}.done"
    cmd = [sys.executable, "-B", GUARD, "run", "--class", "gpu", "--label", f"shield-stream-{label}", "--need-gib", NEED_GIB,
           "--cap-gib", CAP_GIB, "--max-secs", MAX_SECS, "--wait-secs", "3600", "--log", str(log), "--done", str(done),
           "--result-json", str(gj), "--", str(BIN), "--ignored", "--exact", "--nocapture", TEST]
    say(f"launching {label}: {profile} L{layers}, {passes} passes, arms {ARMS}")
    t = time.time()
    cp = subprocess.run(cmd, env=env, stdin=subprocess.DEVNULL)
    with pre.open("a") as f:
        f.write(f"--- after the run, {time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())} ---\n"
                f"loadavg {out(['sysctl', '-n', 'vm.loadavg'])}ds4-bench {out(['pgrep', '-fl', 'ds4-bench']) or '(none)'}\n")
    say(f"{label}: guard exit {cp.returncode} after {time.time() - t:.0f} s")
    return cp.returncode


def main() -> int:
    RAW.mkdir(exist_ok=True)
    if "--inner" not in sys.argv[1:]:
        if (RAW / "run.done").exists():
            print("REFUSED: raw/run.done exists; this run was already made")
            return 97
        with (RAW / "runner.txt").open("w") as f:
            p = subprocess.Popen([sys.executable, "-B", str(Path(__file__).resolve()), "--inner"], stdin=subprocess.DEVNULL,
                                 stdout=f, stderr=subprocess.STDOUT, start_new_session=True)
        rc = p.wait()
        print((RAW / "run.log").read_text() if (RAW / "run.log").exists() else "(no run.log)")
        print(f"runner exit {rc}")
        return rc
    if Path("/tmp/HOLD").exists():
        say("ABORT: /tmp/HOLD exists")
        return 99
    failed = []
    for label, profile, layers, passes in JOBS:
        rc = one(label, profile, layers, passes)
        if rc != 0:
            failed.append(label)
        time.sleep(15)
    say(f"ALL JOBS DONE; failed: {', '.join(failed) or 'none'}")
    (RAW / "run.done").write_text(f"{len(failed)}\n")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
