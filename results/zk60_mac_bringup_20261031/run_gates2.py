#!/usr/bin/env python3
"""Pass 2 of the Mac bring-up gates (see run_gates.py): the full hashline suite
with --no-fail-fast and the R13 loader fixtures that survived the snapshot, and
the Mac-built verifier run directly on four toy receipts made on the Linux box.
Logs in logs2/; logs2/gates.done as in pass 1."""
import json, os, subprocess, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
TREE = os.path.join(HERE, "r19b")
LOGS = os.path.join(HERE, "logs2")
HL = os.path.join(TREE, "hashline", "Cargo.toml")
EX = os.path.join(TREE, "hashline", "target", "release", "examples", "zk60_private_block")
FIX = os.path.join(HERE, "fixtures", "loader-fixtures")
LINUX_RECEIPTS = [
    "zk60_rowfold_20260919/integration/native-block-0",
    "zk60_rowfold_20260919/integration/native-block-1",
    "zk60_private_block_evidence/owner_run1",
    "zk60_attention_integration_20260919/block_public",
]
ENV = dict(os.environ, HL_R13_LOADER_FIXTURES=FIX)

JOBS = [("hashline_all_nofailfast", ["cargo", "test", "--release", "--locked", "--no-fail-fast",
                                     "--manifest-path", HL])]
for d in LINUX_RECEIPTS:
    JOBS.append((f"verify_linux_{d.replace('/', '_')}", [EX, "verify", os.path.join(TREE, "results", d)]))


def child():
    os.makedirs(LOGS, exist_ok=True)
    done = os.path.join(LOGS, "gates.done")
    first_fail = None
    for name, cmd in JOBS:
        t0 = time.time()
        with open(os.path.join(LOGS, f"{name}.log"), "w") as f:
            f.write(f"$ {' '.join(cmd)}\n"); f.flush()
            p = subprocess.run(cmd, stdout=f, stderr=subprocess.STDOUT, cwd=TREE, env=ENV)
        rec = {"job": name, "exit": p.returncode, "secs": round(time.time() - t0, 1)}
        with open(os.path.join(LOGS, "progress.jsonl"), "a") as f:
            f.write(json.dumps(rec) + "\n")
        with open(done + ".partial", "a") as f:
            f.write(f"{name} {p.returncode}\n")
        if p.returncode != 0 and first_fail is None:
            first_fail = name
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
