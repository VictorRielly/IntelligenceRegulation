#!/usr/bin/env python3
"""A36 gates: each step one guarded leaf (guarded.py), in order, every result recorded in raw/<label>.*.

usage: gates.py <group>[,<group>...] [--detach]
  groups: build   release test build with gpu-metal (stops the group on failure)
          check   no-feature `cargo check --tests`
          off     the classifier tests with the switch off (the default), the census and s26 tests
          on      the same classifier tests with HL_A36_CORE_AHEAD=1 in the environment
          g0      the A36 tests (CPU): prove-then-verify, the entropy-boundary order test, the switch, the domain and memory tests
          bin     the release zk60_classify with gpu-metal (as for T1)
          smoke   one resident-server request on the T1 fixture, switch ON, verified by check-serve
--detach: run in its own session with output to raw/gates_<group>.runner.txt and the exit code in raw/gates_<group>.done.
The binary is found from the build log (`Executable unittests src/lib.rs (...)`).
"""
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
WT = HERE.parent.parent
W = WT / "ops/zkp-mvp/gpu-metal/hashline"
CARGO = "/opt/homebrew/bin/cargo"
FIX = f"HL_R13_LOADER_FIXTURES={WT}/results/zk60_1b_native_20261017/r13/loader-fixtures"
CLASSIFIER = "private_block::token_io::classify"  # classify_tests, classify_cli_tests, classify_r14..r18, classify_w16r2, ...


def binary() -> str:
    text = (HERE / "raw" / "g1_build.log").read_text(errors="replace")
    m = re.findall(r"Executable unittests src/lib\.rs \(([^)]+)\)", text)
    if not m:
        sys.exit("no test binary in raw/g1_build.log")
    p = m[-1]
    return p if p.startswith("/") else str(WT / p)


def steps(group: str):
    if group == "build":
        return [("g1_build", ["build", "8", "16", "3600"], [], [CARGO, "test", "--release", "--offline", "--locked", "-j", "2", "--features", "gpu-metal", "--manifest-path", str(W / "Cargo.toml"), "--lib", "--no-run"])]
    if group == "check":
        return [("g1_check_nofeature", ["build", "8", "16", "3600"], [], [CARGO, "check", "--tests", "--offline", "--locked", "-j", "2", "--manifest-path", str(W / "Cargo.toml")])]
    if group == "bin":
        # the release zk60_classify with gpu-metal, as for T1
        return [("g4_bin_build", ["build", "8", "16", "3600"], [], [CARGO, "build", "--release", "--offline", "--locked", "-j", "2", "--features", "gpu-metal", "--manifest-path", str(W / "Cargo.toml"), "--example", "zk60_classify"])]
    if group == "smoke":
        # ONE launch of the resident server on the T1 fixture, switch ON, one request, receipt verified by check-serve (a correctness check, no timing is reported)
        py = "/Users/victorrielly/zk60-artifacts/a28-tools/venv/bin/python"
        return [("g4_smoke_on", ["gpu", "110", "180", "2400"], [], [py, str(HERE / "t1_driver.py"), "--out", str(HERE / "raw/g4_smoke_on"), "--scratch", "/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/39cab447-559b-4f13-981d-d0346f20681a/scratchpad/g4_smoke_on", "--legs", "1", "--warm", "0", "--timed", "1", "--verify-on"])]
    b = binary()
    if group == "g0":
        return [("g0_a36_cpu", ["cpu", "8", "24", "1800"], [FIX], [b, "--test-threads=1", "--nocapture", "a36_"])]
    if group == "metal":
        # the A36 G0 test on the Metal device where a proof's commitments take it (class gpu; HL_GPU_REQUIRED=1 refuses a silent CPU run)
        return [("g0_a36_metal", ["gpu", "16", "32", "1800"], ["HL_GPU_REQUIRED=1", "HL_METAL_TIMING=0", FIX], [b, "--test-threads=1", "--nocapture", "a36_core_ahead"])]
    if group == "off":
        return [
            ("g2_census_s25", ["cpu", "8", "24", "1800"], [FIX], [b, "--test-threads=4", "private_block::s25_tests::"]),
            ("g2_s26", ["cpu", "8", "24", "1800"], [FIX], [b, "--test-threads=4", "private_block::s26_tests::"]),
            ("g2_hash_domain", ["cpu", "8", "24", "1800"], [FIX], [b, "--test-threads=4", "private_block::hash_domain::"]),
            ("g2_classifier_off", ["cpu", "16", "40", "3600"], [FIX, "HL_A36_CORE_AHEAD=0"], [b, "--test-threads=4", "--nocapture", CLASSIFIER]),
        ]
    if group == "on":
        return [("g2_classifier_on", ["cpu", "16", "40", "3600"], [FIX, "HL_A36_CORE_AHEAD=1"], [b, "--test-threads=4", "--nocapture", CLASSIFIER])]
    sys.exit(f"unknown group {group}")


def main() -> int:
    group = sys.argv[1]
    if "--detach" in sys.argv[2:]:
        (HERE / "raw").mkdir(exist_ok=True)
        with (HERE / "raw" / f"gates_{group}.runner.txt").open("w") as f:
            subprocess.Popen([sys.executable, "-B", str(Path(__file__).resolve()), group], stdin=subprocess.DEVNULL, stdout=f, stderr=subprocess.STDOUT, start_new_session=True)
        print(f"detached gates {group}")
        return 0
    done = HERE / "raw" / f"gates_{group}.done"
    done.unlink(missing_ok=True)
    worst = 0
    for label, g, env, leaf in [s for gr in group.split(",") for s in steps(gr)]:
        rc = subprocess.run([sys.executable, "-B", str(HERE / "guarded.py"), label, *g, *env, "--", *leaf]).returncode
        print(f"STEP {label} rc={rc}", flush=True)
        worst = worst or rc
        if rc != 0 and group == "build":
            break
    done.write_text(f"{worst}\n")
    return worst


if __name__ == "__main__":
    sys.exit(main())
