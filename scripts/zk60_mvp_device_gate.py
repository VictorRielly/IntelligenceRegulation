#!/usr/bin/env python3
"""Run strict keyed CUDA parity gates on the restored native candidate."""
import fcntl
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

REPO = Path(__file__).resolve().parents[1]
SRC = REPO / "ops/zkp-mvp/candidate"
OUT = REPO / "results/zk60_mvp_20260929/device-gates"
ENV = {k: v for k, v in os.environ.items() if not k.startswith("HL_")}
ENV.update(CUDA_ROOT="/home/victor/cuda-root", RAYON_NUM_THREADS="2", HL_GPU="1", HL_GPU_REQUIRED="1",
           HL_GPU_CHUNK_ROWS="128", LD_LIBRARY_PATH="/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib")

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    OUT.mkdir(parents=True, exist_ok=False)
    candidates = [p for p in (SRC / "hashline/target/debug/deps").glob("zk60_tagged_gpu_commit-*") if p.is_file() and os.access(p, os.X_OK) and not p.name.endswith(".d")]
    if len(candidates) != 1:
        raise ValueError(f"expected exactly one test executable, got {candidates}")
    binary = candidates[0]
    report = {"state": "waiting-for-heavy-lock", "binary": str(binary), "binary_sha256": sha(binary), "cases": [], "trained_8b_proof": False}
    def save():
        (OUT / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    save()
    with open("/tmp/zk-heavy.lock", "a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        for name, chunk, compact in (("resident", "off", "0"), ("streamed", "force", "0"), ("compact", "force", "1")):
            report.update(state="running", current=name)
            save()
            env = dict(ENV, HL_ZK_CHUNK=chunk, HL_ZK_PAD_COMPACT=compact)
            cmd = [str(binary), "--exact", "tagged_column_hashes_and_full_commitment_match_cpu", "--nocapture", "--test-threads=1"]
            started = time.monotonic()
            log = OUT / (name + ".log")
            with log.open("w") as output:
                code = subprocess.run(cmd, cwd=SRC / "hashline", env=env, stdout=output, stderr=subprocess.STDOUT, timeout=120).returncode
            body = log.read_text()
            passed = code == 0 and "1 passed; 0 failed" in body and "SKIP" not in body
            report["cases"].append({"name": name, "command": cmd, "exit_code": code,
                                    "wall_seconds": time.monotonic() - started, "passed": passed,
                                    "log_sha256": sha(log)})
            save()
            print(f"{name}: {'PASS' if passed else 'FAIL'}", flush=True)
            if not passed:
                report.update(state="failed", current=None)
                save()
                print(body[-4000:], flush=True)
                return 1
    report.update(state="passed", current=None)
    save()
    return 0

if __name__ == "__main__":
    try:
        code = main()
    except Exception as exc:
        OUT.mkdir(parents=True, exist_ok=True)
        (OUT / "error.json").write_text(json.dumps({"error": str(exc)}) + "\n")
        raise
    (OUT / "run.done").write_text(str(code) + "\n")
    sys.exit(code)
