#!/usr/bin/env python3
"""Offline, locked native candidate builds with durable exit records."""
import json
import os
from pathlib import Path
import sys
import time

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
sys.path.insert(0, str(REPO))
from scripts import zk60_guarded_command as guarded
SRC = HERE / "candidate"
OUT = HERE / "build"
OUT.mkdir(exist_ok=True)
TOOLCHAIN = Path("/home/victor/.rustup/toolchains/1.97.0-x86_64-unknown-linux-gnu/bin")
ENV = {k: v for k, v in os.environ.items() if not k.startswith("HL_")}
ENV.update(CUDA_ROOT="/home/victor/cuda-root", RUSTC=str(TOOLCHAIN / "rustc"),
           CARGO_BUILD_JOBS="2", RAYON_NUM_THREADS="2")
STEPS = {
    "gpu-oracle": ["test", "--features", "gpu-cuda", "--test", "zk60_tagged_gpu_commit", "--no-run"],
    "native-lib": ["test", "--release", "--features", "gpu-cuda,stable-weight-storage", "--lib", "--no-run"],
    "stack-cli": ["build", "--release", "--features", "gpu-cuda,stable-weight-storage", "--example", "zk60_private_stack"],
}

def main():
    name = sys.argv[1]
    args = [str(TOOLCHAIN / "cargo"), *STEPS[name], "--offline", "--locked", "-j", "2",
            "--manifest-path", str(SRC / "hashline/Cargo.toml")]
    # Every attempt has its own evidence; earlier passed/interrupted reports
    # at OUT/<name>.json remain intact after a reboot or retry.
    run = OUT / (name + "-" + str(time.time_ns()))
    run.mkdir()
    record = {"state": "waiting-for-guard", "command": args}
    result = run / "report.json"
    guarded.atomic_json(result, record)
    try:
        step = guarded.run(args, cwd=SRC, env=ENV, output=run, label=name)
        code = step["exit_code"]
        record.update(step)
        record["state"] = "passed" if code == 0 else "failed"
    except (OSError, ValueError, RuntimeError, KeyboardInterrupt) as exc:
        code = 1
        record.update(state="interrupted" if isinstance(exc, (guarded.GuardInterrupted, KeyboardInterrupt)) else "failed",
                      error=str(exc), exit_code=code)
    guarded.atomic_json(result, record)
    (run / "run.done").write_text(str(code) + "\n")
    print(json.dumps(record), flush=True)
    print("Build evidence: " + str(run), flush=True)
    if code:
        print(guarded.log_tail(run / (name + ".log")), flush=True)
    return code

if __name__ == "__main__":
    sys.exit(main())
