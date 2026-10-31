#!/usr/bin/env python3
"""[ZK60-METAL M1 gate 2/3] The four seeded golden block proofs (r12_golden_tests:
TinyLlama and Llama-3-8B at T128, with and without DD) on the Mac, first on the
CPU path, then with the commitments on the Apple GPU (HL_GPU=1,
HL_GPU_REQUIRED=1). Each test asserts its proof digest equals the one recorded
on the Linux laptop in R9/R12, so a pass is byte identity CPU(Mac) == CPU(Linux)
and Metal(Mac) == CPU(Linux). HL_PB_TIMING=1 prints the phase clock.

Detached (start_new_session); every leaf through the resource guard; logs and
logs/golden.done (one "<arm> <test> <exit>" line each, then "ALL <0|first fail>")."""
import os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
LOGS = os.path.join(HERE, "logs")
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
GUARD = os.path.join(REPO, "scripts", "zk60_resource_guard.py")
BIN = sys.argv[sys.argv.index("--bin") + 1] if "--bin" in sys.argv else None
TESTS = [
    "r12_golden_seeded_tinyllama_t128_block_is_byte_identical",
    "r12_golden_seeded_tinyllama_t128_dd_block_is_byte_identical",
    "r12_golden_seeded_llama3_8b_t128_block_is_byte_identical",
    "r12_golden_seeded_llama3_8b_t128_dd_block_is_byte_identical",
]
ARMS = [("cpu", "cpu", {"HL_PB_TIMING": "1"}),
        ("metal", "gpu", {"HL_PB_TIMING": "1", "HL_GPU": "1", "HL_GPU_REQUIRED": "1"})]


def child():
    os.makedirs(LOGS, exist_ok=True)
    done = os.path.join(LOGS, "golden.done")
    part = done + ".partial"
    for p in (done, part):
        if os.path.exists(p):
            os.remove(p)
    first = None
    for arm, cls, extra in ARMS:
        for t in TESTS:
            stem = os.path.join(LOGS, f"golden_{arm}_{t.split('_seeded_')[1].split('_block')[0]}")
            env = dict(os.environ)
            env.pop("HL_GPU", None)
            env.pop("HL_GPU_REQUIRED", None)
            env.update(extra)
            cmd = [sys.executable, GUARD, "run", "--class", cls, "--need-gib", "8", "--cap-gib", "40",
                   "--label", f"metal-golden-{arm}", "--wait-secs", "7200", "--max-secs", "3600",
                   "--log", stem + ".log", "--done", stem + ".guard.done", "--result-json", stem + ".guard.json",
                   "--", BIN, "--ignored", "--nocapture", "--test-threads=1", "--exact",
                   f"private_block::r12_golden_tests::{t}"]
            rc = subprocess.run(cmd, env=env, stdout=subprocess.DEVNULL, stderr=open(stem + ".guard.err", "w")).returncode
            with open(part, "a") as f:
                f.write(f"{arm} {t} {rc}\n")
            if rc != 0 and first is None:
                first = f"{arm}:{t}"
    os.replace(part, done)
    with open(done, "a") as f:
        f.write(f"ALL {0 if first is None else first}\n")


if __name__ == "__main__":
    if "--child" in sys.argv:
        child()
    else:
        os.makedirs(LOGS, exist_ok=True)
        p = subprocess.Popen([sys.executable, os.path.abspath(__file__), "--child", "--bin", BIN],
                             start_new_session=True, stdin=subprocess.DEVNULL,
                             stdout=open(os.path.join(LOGS, "golden.runner.out"), "w"), stderr=subprocess.STDOUT)
        print("detached golden runner pid", p.pid)
