#!/usr/bin/env python3
"""Merge gate for the fused RS encoder (co-coordinator, 2026-11-22): the full hashline lib suite on the MERGED tree
of the main checkout, with the R13 loader fixtures, through the resource guard. Detaches so the run survives the
session.

usage: run_suite.py launch <label> [extra test-binary args ...]   (detached; writes raw/<label>.*)
       run_suite.py summary <label>                               (reads raw/<label>.log)

The switch HL_METAL_FUSED_RS is NOT set: this is the default (off) configuration that everyone runs after the merge.
"""
import os
import re
import subprocess
import sys
import time
from pathlib import Path

REPO = "/Users/victorrielly/IntelligenceRegulation"
HERE = Path(__file__).resolve().parent
RAW = HERE / "raw"
GUARD = REPO + "/scripts/zk60_resource_guard.py"
CARGO = "/opt/homebrew/bin/cargo"
MANIFEST = REPO + "/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml"
FIX = REPO + "/results/zk60_1b_native_20261017/r13/loader-fixtures"


def launch(label, extra):
    RAW.mkdir(parents=True, exist_ok=True)
    log, gj, done = RAW / (label + ".log"), RAW / (label + ".guard.json"), RAW / (label + ".done")
    for p in (log, gj, done):
        p.unlink(missing_ok=True)
    st = subprocess.run([sys.executable, "-B", GUARD, "status"], capture_output=True, text=True).stdout
    (RAW / (label + ".status_pre.txt")).write_text(time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()) + "\n" + st)
    head = subprocess.run(["git", "rev-parse", "HEAD"], cwd=REPO, capture_output=True, text=True).stdout.strip()
    (RAW / (label + ".head.txt")).write_text(head + "\n")
    env = os.environ.copy()
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    env["HL_R13_LOADER_FIXTURES"] = FIX
    env.pop("HL_METAL_FUSED_RS", None)
    leaf = [CARGO, "test", "--manifest-path", MANIFEST, "--release", "--offline", "--locked", "--features", "gpu-metal",
            "--lib", "--", "--test-threads=8"] + list(extra)
    cmd = [sys.executable, "-B", GUARD, "run", "--class", "gpu", "--label", "fused-merge-" + label, "--need-gib", "16",
           "--cap-gib", "32", "--max-secs", "3600", "--wait-secs", "21600", "--log", str(log), "--done", str(done),
           "--result-json", str(gj), "--"] + leaf
    p = subprocess.Popen(cmd, env=env, stdin=subprocess.DEVNULL, stdout=open(RAW / (label + ".runner.txt"), "w"),
                         stderr=subprocess.STDOUT, start_new_session=True)
    print("launched", label, "pid", p.pid, "head", head[:8])


def summary(label):
    log = (RAW / (label + ".log")).read_text(errors="replace")
    done = RAW / (label + ".done")
    print("done marker:", done.read_text().strip() if done.exists() else "absent (still running)")
    for m in re.finditer(r"test result: (\w+)\. (\d+) passed; (\d+) failed; (\d+) ignored; (\d+) measured; (\d+) filtered out", log):
        print("result:", m.group(0))
    fails = sorted(set(re.findall(r"^test (\S+) \.\.\. FAILED", log, re.M)))
    print("failed tests:", len(fails))
    for f in fails:
        print("  ", f)


if __name__ == "__main__":
    if sys.argv[1] == "launch":
        launch(sys.argv[2], sys.argv[3:])
    else:
        summary(sys.argv[2])
