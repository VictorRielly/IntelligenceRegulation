#!/usr/bin/env python3
"""Mac (M3 Ultra, arm64 macOS) CPU bring-up gates for the frozen production
tree ops/zkp-mvp/token-io-r19b, run on a scratch copy so test writes never
touch the tracked tree. Detached via start_new_session (macOS has no setsid
or flock CLI). Each job tees to logs/<name>.log; logs/gates.done holds one
line per job "<name> <exit>" and a final "ALL <0|first failing job>".

usage: run_gates.py            (parent: re-spawns detached, prints child PID)
       run_gates.py --child    (the actual runner)
"""
import json, os, subprocess, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
TREE = os.path.join(HERE, "r19b")
LOGS = os.path.join(HERE, "logs")
OUT = os.path.join(HERE, "out")
ZC = os.path.join(TREE, "zkp-core", "Cargo.toml")
HL = os.path.join(TREE, "hashline", "Cargo.toml")
EX = os.path.join(TREE, "hashline", "target", "release", "examples", "zk60_private_block")
BLOCK = os.path.join(OUT, "block")

JOBS = [
    ("env", ["/bin/sh", "-c", "uname -m; sw_vers; sysctl -n hw.memsize hw.ncpu machdep.cpu.brand_string; rustc -Vv; cargo -V"]),
    ("zkp_core_test", ["cargo", "test", "--release", "--locked", "--manifest-path", ZC]),
    ("hashline_lib_test", ["cargo", "test", "--release", "--locked", "--manifest-path", HL, "--lib"]),
    ("hashline_all_test", ["cargo", "test", "--release", "--locked", "--manifest-path", HL]),
    ("hashline_storage_lib_test", ["cargo", "test", "--release", "--locked", "--manifest-path", HL, "--features", "stable-weight-storage", "--lib"]),
    ("build_cli_and_example", ["cargo", "build", "--release", "--locked", "--manifest-path", HL, "--bin", "hashline", "--example", "zk60_private_block"]),
    ("block_prove", [EX, "prove", BLOCK]),
    ("block_verify_fresh_process", [EX, "verify", BLOCK]),
    ("block_digests", ["/bin/sh", "-c", f"ls -l {BLOCK}; shasum -a 256 {BLOCK}/*"]),
]


def child():
    os.makedirs(LOGS, exist_ok=True)
    os.makedirs(OUT, exist_ok=True)
    done = os.path.join(LOGS, "gates.done")
    if os.path.exists(done):
        os.remove(done)
    summary = []
    first_fail = None
    for name, cmd in JOBS:
        log = os.path.join(LOGS, f"{name}.log")
        t0 = time.time()
        with open(log, "w") as f:
            f.write(f"$ {' '.join(cmd)}\n")
            f.flush()
            p = subprocess.run(cmd, stdout=f, stderr=subprocess.STDOUT, cwd=TREE)
        dt = time.time() - t0
        rec = {"job": name, "exit": p.returncode, "secs": round(dt, 1)}
        summary.append(rec)
        with open(os.path.join(LOGS, "progress.jsonl"), "a") as f:
            f.write(json.dumps(rec) + "\n")
        with open(done + ".partial", "a") as f:
            f.write(f"{name} {p.returncode}\n")
        if p.returncode != 0 and first_fail is None:
            first_fail = name
            # build/test failures do not stop later independent gates, but a
            # failed build makes prove/verify meaningless
            if name == "build_cli_and_example":
                break
    with open(os.path.join(LOGS, "summary.json"), "w") as f:
        json.dump(summary, f, indent=1)
    os.replace(done + ".partial", done)
    with open(done, "a") as f:
        f.write(f"ALL {0 if first_fail is None else first_fail}\n")


if __name__ == "__main__":
    if "--child" in sys.argv:
        child()
    else:
        os.makedirs(LOGS, exist_ok=True)
        p = subprocess.Popen([sys.executable, os.path.abspath(__file__), "--child"],
                             start_new_session=True, stdin=subprocess.DEVNULL,
                             stdout=open(os.path.join(LOGS, "runner.out"), "w"),
                             stderr=subprocess.STDOUT)
        print("detached runner pid", p.pid)
