#!/usr/bin/env python3
"""Merge gate for agy/host-g5g4g6 (co-coordinator, 2026-11-23): the full hashline lib suite on a checkout of the MERGE COMMIT,
with the R13 loader fixtures and no switch set (the command of results/zk60_composed_merge_20261122/run_suite.py), the same suite
once more with HL_HOST_FAST=1 in the environment (every proof test then takes the fast path), then the change's own gates and the
fast sumcheck chain's, each in a fresh process, then the Metal commit integration test with the switch unset and set. One guarded
gpu job, detached.

usage: run_gate.py launch <label> <checkout>     (detached; writes raw/<label>.*)
       run_gate.py leaf <checkout>               (what the guard runs; prints one "=== STEP" line per step)
       run_gate.py summary <label>               (reads raw/<label>.log)

Pass: the failures of both suite runs are only the two known fixture ones, and every other step exits 0 with at least one test run and
none failed.
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
FIX = REPO + "/results/zk60_1b_native_20261017/r13/loader-fixtures"
SWITCHES = ("HL_METAL_FUSED_RS", "HL_METAL_SPARSE_FOLD", "HL_METAL_SPARSE_FOLD_REG8", "HL_METAL_OPEN_FAST", "HL_METAL_OPEN_SKIP_TABLES",
            "HL_METAL_OPEN_HOST_GATHER", "HL_METAL_SC_CHAIN_FAST", "HL_METAL_SC_TG", "HL_METAL_BATCH", "HL_METAL_BATCH_TAIL_US",
            "HL_METAL_TAIL_BUDGET_US", "HL_METAL_QUEUES", "HL_METAL_SPIN_US", "HL_METAL_TIMING", "HL_A27_GPU_TRACE", "HL_A27_FOLD",
            "HL_A36_CORE_AHEAD", "HL_HOST_FAST", "HL_ARG_LAZY", "HL_GPU", "HL_GPU_REQUIRED", "ZK60_GUARD_POLL_SECS")
KNOWN = {"private_block::review_tests::a_toy_receipt_made_before_f12_is_refused",
         "private_block::trained_block::accuracy::profile_tests::accuracy_v2_dense_witness_matches_all_nineteen_independent_integer_traces"}
# (step name, test-name filter, extra environment, extra cargo args before "--")
GATES = [
    ("hf-pub-gen", "host_fast_m1_pub_gen_all_7_kinds_and_direct_total_gpu", {"HL_GPU": "1", "HL_GPU_REQUIRED": "1"}),
    ("hf-golden", "host_fast_w16r2_rung_golden", {"HL_GPU": "1", "HL_GPU_REQUIRED": "1", "HL_METAL_TIMING": "1"}),
    ("hf-flag-matrix", "host_fast_m3_flag_matrix_golden", {"HL_GPU": "1", "HL_GPU_REQUIRED": "1"}),
    ("hf-call-sites", "host_fast_all_call_sites_byte_identical", {"HL_GPU": "1", "HL_GPU_REQUIRED": "1"}),
    ("hf-r13-shield", "host_fast_m2_r13_shield_byte_identical", {"HL_GPU": "1", "HL_GPU_REQUIRED": "1"}),
    ("sc-golden-hf1", "sc_chain_fast_w16r2_rung_golden", {"HL_GPU": "1", "HL_GPU_REQUIRED": "1", "HL_HOST_FAST": "1"}),
    ("sc-golden", "sc_chain_fast_w16r2_rung_golden", {"HL_GPU_REQUIRED": "1"}),
    ("sc-call-sites", "sc_chain_fast_all_call_sites_byte_identical", {"HL_GPU_REQUIRED": "1"}),
]


def base_env():
    env = os.environ.copy()
    for k in SWITCHES:
        env.pop(k, None)
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    env["HL_R13_LOADER_FIXTURES"] = FIX
    return env


def leaf(checkout):
    manifest = checkout + "/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml"
    common = [CARGO, "test", "--manifest-path", manifest, "--release", "--offline", "--locked", "--features", "gpu-metal"]
    bad = 0

    def step(name, argv, extra):
        nonlocal bad
        print(f"=== STEP {name} START {time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())} env {extra} argv {' '.join(argv[len(common) - 2:])}", flush=True)
        rc = subprocess.run(argv, env=dict(base_env(), **extra), stdin=subprocess.DEVNULL).returncode
        print(f"=== STEP {name} EXIT {rc} {time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}", flush=True)
        return rc

    step("suite", common + ["--lib", "--", "--test-threads=8"], {})          # judged by the summary (two known failures)
    step("suite-hf1", common + ["--lib", "--", "--test-threads=8"], {"HL_HOST_FAST": "1"})   # judged by the summary likewise
    for name, filt, extra in GATES:
        if step(name, common + ["--lib", filt, "--", "--ignored", "--nocapture", "--test-threads=1"], extra) != 0:
            bad += 1
    if step("metal-commit", common + ["--test", "zk60_metal_commit", "--", "--test-threads=1"], {"HL_GPU_REQUIRED": "1"}) != 0:
        bad += 1
    if step("metal-commit-hf1", common + ["--test", "zk60_metal_commit", "--", "--test-threads=1"], {"HL_GPU_REQUIRED": "1", "HL_HOST_FAST": "1"}) != 0:
        bad += 1
    return 1 if bad else 0


def launch(label, checkout):
    RAW.mkdir(parents=True, exist_ok=True)
    log, gj, done = RAW / (label + ".log"), RAW / (label + ".guard.json"), RAW / (label + ".done")
    for p in (log, gj, done):
        p.unlink(missing_ok=True)
    st = subprocess.run([sys.executable, "-B", GUARD, "status"], capture_output=True, text=True).stdout
    (RAW / (label + ".status_pre.txt")).write_text(time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()) + "\n" + st)
    head = subprocess.run(["git", "rev-parse", "HEAD"], cwd=checkout, capture_output=True, text=True).stdout.strip()
    (RAW / (label + ".head.txt")).write_text(f"{head}\ncheckout {checkout}\n")
    cmd = [sys.executable, "-B", GUARD, "run", "--class", "gpu", "--label", "hostfast-merge-" + label, "--need-gib", "16",
           "--cap-gib", "32", "--max-secs", "7200", "--wait-secs", "21600", "--log", str(log), "--done", str(done),
           "--result-json", str(gj), "--", sys.executable, "-B", str(Path(__file__).resolve()), "leaf", checkout]
    p = subprocess.Popen(cmd, env=base_env(), stdin=subprocess.DEVNULL, stdout=open(RAW / (label + ".runner.txt"), "w"),
                         stderr=subprocess.STDOUT, start_new_session=True)
    print("launched", label, "pid", p.pid, "checkout head", head[:8])


def summary(label):
    log = (RAW / (label + ".log")).read_text(errors="replace")
    done = RAW / (label + ".done")
    print("done marker:", done.read_text().strip() if done.exists() else "absent (still running)")
    parts = re.split(r"^=== STEP (\S+) START [^\n]*\n", log, flags=re.M)
    ok = True
    for i in range(1, len(parts), 2):
        name, body = parts[i], parts[i + 1]
        ex = re.search(r"^=== STEP \S+ EXIT (-?\d+)", body, re.M)
        res = re.findall(r"test result: (\w+)\. (\d+) passed; (\d+) failed; (\d+) ignored; (\d+) measured; (\d+) filtered out", body)
        fails = sorted(set(re.findall(r"^test (\S+) \.\.\. FAILED", body, re.M)))
        passed = sum(int(r[1]) for r in res)
        failed = sum(int(r[2]) for r in res)
        if name in ("suite", "suite-hf1"):
            good = bool(res) and set(fails) <= KNOWN and failed == len(fails)
            print(f"{name}: exit {ex.group(1) if ex else '?'}; {passed} passed, {failed} failed, {sum(int(r[3]) for r in res)} ignored; failed tests: {fails or 'none'}"
                  f" -> {'only known fixture failures' if good and fails else ('clean' if good else 'NEW FAILURE or no result')}")
        else:
            good = bool(ex) and ex.group(1) == "0" and passed >= 1 and failed == 0
            print(f"{name}: exit {ex.group(1) if ex else '?'}; {passed} passed, {failed} failed -> {'ok' if good else 'NOT OK'}")
        ok &= good
    print("GATE:", "GREEN" if ok and done.exists() and len(parts) >= 2 * (len(GATES) + 4) else "NOT GREEN (or unfinished)")


if __name__ == "__main__":
    if sys.argv[1] == "launch":
        launch(sys.argv[2], sys.argv[3])
    elif sys.argv[1] == "leaf":
        sys.exit(leaf(sys.argv[2]))
    else:
        summary(sys.argv[2])
