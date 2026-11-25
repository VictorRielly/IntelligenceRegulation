#!/usr/bin/env python3
"""Post-merge Wave-2 8B benchmark runner (B0=acceeb94c vs B1=9291bb085 [0 Rust diff vs 9fbc85292]).

Modes:
  set1   Two-binary 3-arm fresh-process set (lead-in A0, then A1, B1, C1, C2, B2, A2; 1 pass each)
         run sequentially inside a single guarded --class gpu window.
  set2   Single-process 6-pass alternating B1 replication (hw0 vs hw1+ad0), run inside its own
         guarded --class gpu window after >=12 s cooldown.
"""
import hashlib
import json
import os
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
RAW = HERE / "raw"
ROOT = Path("/Users/victorrielly/IntelligenceRegulation")
GUARD = str(ROOT / "scripts/zk60_resource_guard.py")

B0 = ROOT / ".agy-worktrees/w2-8b-base/ops/zkp-mvp/gpu-metal/hashline/target/release/deps/hashline-99331253074f9a28"
B0_SHA = "1fd3e12f827d30be0e0c48abf2d74f3d272db35e4bbca5e093da7b42d1180c4a"

B1 = ROOT / ".agy-worktrees/wave2-8b-postmerge/ops/zkp-mvp/gpu-metal/hashline/target/release/deps/hashline-47108cbd7bf5814a"
B1_SHA = "d4fb1ca9c14a3019350c4ac2a557178f612d5fb2923a626096ef2ea69efaf71b"

TEST = "private_block::run::fork::tests::a22::a22_stream_ab"

BASE_ENV = {
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
    "RAYON_NUM_THREADS",
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
    "HL_A26_PCS_SPARSE",
)

ARM_A = "serve8+lanes2+ba1+frs1+sf1+sc1+hf1"
ARM_B = "serve8+lanes2+ba1+frs1+sf1+sc1+hf1"
ARM_C = "serve8+lanes2+ba1+frs1+sf1+sc1+hf1+hw1+ad0"

SET1_LEGS = [
    ("A0_leadin", B0, ARM_A),
    ("A1", B0, ARM_A),
    ("B1", B1, ARM_B),
    ("C1", B1, ARM_C),
    ("C2", B1, ARM_C),
    ("B2", B1, ARM_B),
    ("A2", B0, ARM_A),
]

SET2_ARMS = (
    "serve8+lanes2+ba1+frs1+sf1+sc1+hf1+q0+hw0,"
    "serve8+lanes2+ba1+frs1+sf1+sc1+hf1+q0+hw1+ad0"
)


def sha256(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def clean_env() -> dict:
    env = os.environ.copy()
    for k in STRIP:
        env.pop(k, None)
    for k in list(env):
        if k.startswith("HL_"):
            env.pop(k, None)
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    env.update(BASE_ENV)
    return env


def run_inner_set1() -> int:
    """Runs inside the guarded GPU job: executes all 7 fresh-process legs sequentially."""
    RAW.mkdir(parents=True, exist_ok=True)
    meta = []
    for idx, (leg, binary, arm) in enumerate(SET1_LEGS):
        t0 = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        t0_m = time.monotonic()
        env = clean_env()
        env["HL_A22_AB"] = arm
        env["HL_A22_AB_PASSES"] = "1"
        leg_log = RAW / f"set1_{idx}_{leg}.log"
        print(f"=== SET1 LEG {idx} {leg} bin={binary.name} arm={arm} start={t0} ===", flush=True)
        with leg_log.open("wb") as lf:
            cp = subprocess.run(
                [str(binary), "--ignored", "--exact", "--nocapture", TEST],
                env=env,
                stdin=subprocess.DEVNULL,
                stdout=lf,
                stderr=subprocess.STDOUT,
            )
        dt = time.monotonic() - t0_m
        t1 = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        print(f"=== SET1 LEG {idx} {leg} exit={cp.returncode} wall={dt:.2f}s end={t1} ===", flush=True)
        meta.append({
            "idx": idx,
            "leg": leg,
            "bin": str(binary),
            "arm": arm,
            "exit": cp.returncode,
            "wall_s": round(dt, 3),
            "ts_start": t0,
            "ts_end": t1,
            "log": str(leg_log),
        })
        if cp.returncode != 0:
            (RAW / "set1_meta.json").write_text(json.dumps(meta, indent=2) + "\n")
            return cp.returncode
        if idx + 1 < len(SET1_LEGS):
            time.sleep(2.0)
    (RAW / "set1_meta.json").write_text(json.dumps(meta, indent=2) + "\n")
    return 0


def preflight_and_verify() -> int:
    if Path("/tmp/HOLD").exists():
        print("ABORT: /tmp/HOLD exists", file=sys.stderr)
        return 99
    if subprocess.run(["pgrep", "-f", "[d]s4-bench"], capture_output=True).returncode == 0:
        print("ABORT: ds4-bench is running", file=sys.stderr)
        return 97
    g0 = sha256(B0)
    g1 = sha256(B1)
    if g0 != B0_SHA:
        print(f"ABORT: B0 SHA mismatch: {g0} != {B0_SHA}", file=sys.stderr)
        return 98
    if g1 != B1_SHA:
        print(f"ABORT: B1 SHA mismatch: {g1} != {B1_SHA}", file=sys.stderr)
        return 98
    return 0


def out(cmd) -> str:
    return subprocess.run(cmd, capture_output=True, text=True).stdout


def run_guarded_set1() -> int:
    RAW.mkdir(parents=True, exist_ok=True)
    rc = preflight_and_verify()
    if rc != 0:
        return rc
    pre = RAW / "set1.status_pre.txt"
    pre.write_text(
        f"{time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}\n"
        f"B0 {B0} sha256 {B0_SHA}\n"
        f"B1 {B1} sha256 {B1_SHA}\n"
        f"legs {[(l, b.name, a) for l, b, a in SET1_LEGS]}\n"
        f"base_env {BASE_ENV}\n"
        f"--- guard status ---\n{out([sys.executable, '-B', GUARD, 'status'])}"
        f"--- sysctl -n vm.loadavg ---\n{out(['sysctl', '-n', 'vm.loadavg'])}"
    )
    log, gj, done = RAW / "set1.log", RAW / "set1.guard.json", RAW / "set1.done"
    for p in (log, gj, done):
        p.unlink(missing_ok=True)
    cmd = [
        sys.executable, "-B", GUARD, "run",
        "--class", "gpu", "--label", "agy-w2-8b-pm-set1",
        "--need-gib", "80", "--cap-gib", "110",
        "--max-secs", "1800", "--wait-secs", "3600",
        "--log", str(log), "--done", str(done), "--result-json", str(gj),
        "--", sys.executable, "-B", str(Path(__file__).resolve()), "_inner_set1",
    ]
    cp = subprocess.run(cmd, stdin=subprocess.DEVNULL)
    with pre.open("a") as f:
        f.write(
            f"--- after set1, {time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())} ---\n"
            f"loadavg {out(['sysctl', '-n', 'vm.loadavg'])}"
        )
    return cp.returncode


def run_guarded_set2() -> int:
    RAW.mkdir(parents=True, exist_ok=True)
    rc = preflight_and_verify()
    if rc != 0:
        return rc
    env = clean_env()
    env["HL_A22_AB"] = SET2_ARMS
    env["HL_A22_AB_PASSES"] = "6"
    pre = RAW / "set2.status_pre.txt"
    pre.write_text(
        f"{time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}\n"
        f"B1 {B1} sha256 {B1_SHA}\n"
        f"arms {SET2_ARMS}\n"
        f"passes 6\n"
        f"base_env {BASE_ENV}\n"
        f"--- guard status ---\n{out([sys.executable, '-B', GUARD, 'status'])}"
        f"--- sysctl -n vm.loadavg ---\n{out(['sysctl', '-n', 'vm.loadavg'])}"
    )
    log, gj, done = RAW / "set2.log", RAW / "set2.guard.json", RAW / "set2.done"
    for p in (log, gj, done):
        p.unlink(missing_ok=True)
    cmd = [
        sys.executable, "-B", GUARD, "run",
        "--class", "gpu", "--label", "agy-w2-8b-pm-set2",
        "--need-gib", "80", "--cap-gib", "110",
        "--max-secs", "1800", "--wait-secs", "3600",
        "--log", str(log), "--done", str(done), "--result-json", str(gj),
        "--", str(B1), "--ignored", "--exact", "--nocapture", TEST,
    ]
    cp = subprocess.run(cmd, env=env, stdin=subprocess.DEVNULL)
    with pre.open("a") as f:
        f.write(
            f"--- after set2, {time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())} ---\n"
            f"loadavg {out(['sysctl', '-n', 'vm.loadavg'])}"
        )
    return cp.returncode


def main() -> int:
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    if mode == "set1":
        return run_guarded_set1()
    if mode == "_inner_set1":
        return run_inner_set1()
    if mode == "set2":
        return run_guarded_set2()
    print(f"usage: {sys.argv[0]} {{set1|set2}}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
