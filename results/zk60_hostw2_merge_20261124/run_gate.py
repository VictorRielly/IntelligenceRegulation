#!/usr/bin/env python3
"""Merge gate for agy/host-wave2 (co-coordinator, 2026-11-24): the full hashline lib suite on a checkout of the MERGE COMMIT,
with the R13 loader fixtures and no switch set (the command of results/zk60_composed_merge_20261122/run_suite.py), the same suite
once more with HL_HOST_FAST=1, HL_CLASSIFY_HOST_FAST=1 and HL_HOST_FAST_W2=1 in the environment (every proof test then takes the
fast paths), then the branch's eight fresh-process gates with the environment its author lists (coordination entry
2026-11-24T05:11:30Z), the two host-fast gates again as the host-fast merge ran them, three classifier tests, each in a fresh
process, then the Metal commit integration test with the switches unset and set. One guarded
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
            "HL_A36_CORE_AHEAD", "HL_HOST_FAST", "HL_CLASSIFY_HOST_FAST", "HL_HOST_FAST_W2", "HL_HOST_FAST_ASYNC_DROP", "HL_A28_SEAL_AHEAD", "HL_ARG_LAZY", "HL_GPU", "HL_GPU_REQUIRED", "ZK60_GUARD_POLL_SECS")
KNOWN = {"private_block::review_tests::a_toy_receipt_made_before_f12_is_refused",
         "private_block::trained_block::accuracy::profile_tests::accuracy_v2_dense_witness_matches_all_nineteen_independent_integer_traces"}
# (step name, exact test path or filter, extra environment, extra libtest flags)
BOTH = {"HL_HOST_FAST": "1", "HL_CLASSIFY_HOST_FAST": "1"}
ALL3 = dict(BOTH, HL_HOST_FAST_W2="1")
HW = {"HL_HOST_FAST": "1", "HL_HOST_FAST_W2": "1"}
HF = {"HL_HOST_FAST": "1"}
T = "private_block::token_io::"
W = "private_block::w16r2_tests::"
IG = ["--ignored", "--exact"]
GATES = [
    # the author's eight, with the author's environment
    ("unit-isolation-unset", T + "classify_cli_tests::classify_host_fast_unit_isolation_and_switch_off_gate", {}, IG),
    ("unit-isolation-all3", T + "classify_cli_tests::classify_host_fast_unit_isolation_and_switch_off_gate", ALL3, IG),
    ("ch-verifier-isolation", T + "classify_cli::serve::tests::classify_host_fast_verifier_isolation_and_serve_gate", BOTH, IG),
    ("ch-plus-w2-serve", T + "classify_cli::serve::tests::classify_host_fast_plus_w2_serve_gate", ALL3, IG),
    ("w2-call-sites", W + "host_fast_w2_all_call_sites_byte_identical", HW, IG),
    ("w2-golden", W + "host_fast_w2_rung_golden", HW, IG),
    # added with the fix commit 9f70ff137 (author's entry 2026-11-24T08:49:10Z; paths as the fix read lists them)
    ("all3-verifier-isolation", W + "host_fast_all_three_switches_verifier_isolation_gate", ALL3, IG),  # the runner adds --test-threads=1 and --nocapture to every gate
    ("w2-alone-serve", T + "classify_cli::serve::tests::host_fast_w2_alone_classify_serve_gate", {"HL_HOST_FAST_W2": "1"}, IG),
    ("w2-trained-d55-sealing", "private_block::run::fork::tests::host_fast_w2_trained_block_d55_sealing_byte_identical", {}, IG),
    ("w2-rope-const-pubgen", W + "host_fast_w2_rope_and_const_pub_gen_gpu", HW, IG),
    ("hf-call-sites-author", W + "host_fast_all_call_sites_byte_identical", HF, IG),
    ("hf-golden-author", W + "host_fast_w16r2_rung_golden", HF, IG),
    # the two host-fast gates as the host-fast and classifier merges ran them
    ("hf-golden", "host_fast_w16r2_rung_golden", {"HL_GPU": "1", "HL_GPU_REQUIRED": "1", "HL_METAL_TIMING": "1"}, ["--ignored"]),
    ("hf-call-sites", "host_fast_all_call_sites_byte_identical", {"HL_GPU": "1", "HL_GPU_REQUIRED": "1"}, ["--ignored"]),
    # three classifier tests of the suite, alone
    ("ch-end-to-end", T + "classify_cli_tests::classify_host_fast_end_to_end_rung_byte_identical_and_verified", dict(BOTH, HL_METAL_TIMING="1"), ["--exact"]),
    ("ch-writer-faults", T + "classify_cli_tests::classify_host_fast_c2_writer_err_panic_and_prover_abort_cleanup", BOTH, ["--exact"]),
    ("ch-serve-seal-ahead", T + "classify_cli::serve::tests::classify_host_fast_serve_and_check_serve_both_seal_ahead_modes", BOTH, ["--exact"]),
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
    step("suite-on", common + ["--lib", "--", "--test-threads=8"], ALL3)   # judged by the summary likewise
    for name, filt, extra, flags in GATES:
        if step(name, common + ["--lib", filt, "--", *flags, "--nocapture", "--test-threads=1"], extra) != 0:
            bad += 1
    if step("metal-commit", common + ["--test", "zk60_metal_commit", "--", "--test-threads=1"], {"HL_GPU_REQUIRED": "1"}) != 0:
        bad += 1
    if step("metal-commit-on", common + ["--test", "zk60_metal_commit", "--", "--test-threads=1"], dict(ALL3, HL_GPU_REQUIRED="1")) != 0:
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
    cmd = [sys.executable, "-B", GUARD, "run", "--class", "gpu", "--label", "hostw2-merge-" + label, "--need-gib", "16",
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
        if name in ("suite", "suite-on"):
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
