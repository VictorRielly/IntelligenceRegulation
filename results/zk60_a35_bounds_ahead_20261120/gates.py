#!/usr/bin/env python3
"""A35 gates: each step one guarded leaf (guarded.py), in order, every result recorded in raw/<label>.*.

usage: gates.py <group> [--detach]
  groups: build   G1 release test build with gpu-metal (stops the group on failure)
          check   G1 no-feature `cargo check --tests`
          focus   the new a35 test (CPU), the generator census and s25 / s26 tests, the A22 stream tests (CPU)
          device  the a35 test on the Metal device (ignored; by name, class gpu)
          suite   the full non-ignored suite on the new binary, then the three tests A33 named
--detach: start this script in its own session (it survives the launching session) with output to
raw/gates_<group>.runner.txt and the exit code in raw/gates_<group>.done, and return at once.
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
THREE = ["a_toy_receipt_made_before_f12_is_refused", "accuracy_v2_dense_witness_matches_all_nineteen_independent_integer_traces",
         "review_n_r6_b_a_stale_statement_writing_dir_is_removed_or_refused_by_name"]


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
    b = binary()
    if group == "focus":
        return [
            ("g3_a35_cpu", ["cpu", "8", "24", "1800"], [FIX], [b, "--test-threads=1", "--nocapture", "a35_the_commit_phase_before_the_prover_turn_gives_the_same_words"]),
            ("g4_census_s25", ["cpu", "8", "24", "1800"], [FIX], [b, "--test-threads=4", "private_block::s25_tests::"]),
            ("g4_s26", ["cpu", "8", "24", "1800"], [FIX], [b, "--test-threads=4", "private_block::s26_tests::"]),
            ("g4_a22_cpu", ["cpu", "8", "24", "1800"], [FIX], [b, "--test-threads=2", "run::fork::tests::a22::"]),
        ]
    if group == "device":
        return [("g3_a35_metal", ["gpu", "16", "32", "1800"], ["HL_GPU_REQUIRED=1", "HL_METAL_TIMING=0", FIX], [b, "--ignored", "--exact", "--nocapture", "--test-threads=1", "private_block::run::fork::tests::a22::a35_the_commit_phase_before_the_prover_turn_gives_the_same_words_on_the_device"])]
    if group == "suite":
        return [
            ("g2_full_suite", ["cpu", "24", "60", "5400"], [FIX], [b, "--test-threads=8"]),
            ("g2_three_known", ["cpu", "16", "40", "1800"], [FIX], [b, "--test-threads=3", *THREE]),
        ]
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
    # a comma-separated list of groups runs them in order (each step recorded; none stops the next group)
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
