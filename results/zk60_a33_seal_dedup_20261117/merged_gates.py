#!/usr/bin/env python3
"""A33 rerun of G1 (no-feature check), G2, G3, G4 on the merged tree (base 2ae06f54): each step through guarded.py, in order,
every result recorded, a failing step does not stop the next (the gates are read afterwards).
BIN_P = merged patched binary; BIN_B = merged tree with `if build_checked && false {` (the old behaviour, plus the new tests);
BIN_U = the reference binary hashline-a90b6cf7715dc2a7 (unpatched, read-only, from the main checkout)."""
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
W = "/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a4d782b46866ea303/ops/zkp-mvp/gpu-metal/hashline"
BIN_P = f"{W}/target/release/deps/hashline-4ff65cafe9d88959"
BIN_B = "<scratch>/target_base/release/deps/hashline-4ff65cafe9d88959"  # the agent's scratch directory (CARGO_TARGET_DIR of the old-behaviour build); path scrubbed
BIN_U = "/Users/victorrielly/IntelligenceRegulation/ops/zkp-mvp/gpu-metal/hashline/target/release/deps/hashline-a90b6cf7715dc2a7"
FIX = "HL_R13_LOADER_FIXTURES=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a4d782b46866ea303/results/zk60_1b_native_20261017/r13/loader-fixtures"
M4 = ["HL_GPU_REQUIRED=1", "HL_METAL_TIMING=0", "HL_M4_PHASES=1", "HL_M4_WARM_PASSES=1",
      "HL_M4_PROFILES=R13_SHIELD_T128_H24,R13_8B_T128_H24,W16_SHIELD_T128_H24,W16_8B_T128_H24,W16R2_SHIELD_T128_H24,W16R2_8B_T128_H24"]
M4T = "private_block::slot_ir::accuracy::tests::m4_trained_accuracy_block_cpu_and_metal_digests_and_times"
E8 = "private_block::run::fork::tests::a33_the_8b_sealing_pass_summary_on_the_cpu_and_on_the_device"
THREE = ["a_toy_receipt_made_before_f12_is_refused", "accuracy_v2_dense_witness_matches_all_nineteen_independent_integer_traces",
         "review_n_r6_b_a_stale_statement_writing_dir_is_removed_or_refused_by_name"]

steps = [
    ("m_g1_check_nofeature", ["build", "8", "16", "1800"], [], ["/opt/homebrew/bin/cargo", "check", "--tests", "--offline", "--locked", "-j", "2", "--manifest-path", f"{W}/Cargo.toml"]),
    ("m_g4_a33_patched", ["cpu", "8", "16", "600"], [FIX], [BIN_P, "--test-threads=1", "--nocapture", "fork::tests::a33_"]),
    ("m_g4_a33_baseline", ["cpu", "8", "16", "600"], [FIX], [BIN_B, "--test-threads=1", "--nocapture", "fork::tests::a33_"]),
    ("m_g4_8b_seal_patched", ["gpu", "24", "40", "900"], ["HL_GPU_REQUIRED=1", "HL_PB_ORACLE=0", "HL_METAL_TIMING=0"], [BIN_P, "--ignored", "--exact", "--nocapture", "--test-threads=1", E8]),
    ("m_g4_8b_seal_baseline", ["gpu", "24", "40", "900"], ["HL_GPU_REQUIRED=1", "HL_PB_ORACLE=0", "HL_METAL_TIMING=0"], [BIN_B, "--ignored", "--exact", "--nocapture", "--test-threads=1", E8]),
    ("m_g4_m4_trained_patched", ["gpu", "36", "48", "2400"], M4, [BIN_P, "--ignored", "--exact", "--nocapture", "--test-threads=1", M4T]),
    ("m_g4_m4_trained_unpatched", ["gpu", "36", "48", "2400"], M4, [BIN_U, "--ignored", "--exact", "--nocapture", "--test-threads=1", M4T]),
    ("m_g2_three_known_unpatched", ["cpu", "16", "40", "1800"], [FIX], [BIN_U, "--test-threads=3", *THREE]),
    ("m_g2_three_known_patched", ["cpu", "16", "40", "1800"], [FIX], [BIN_P, "--test-threads=3", *THREE]),
    ("m_g2_full_suite_patched", ["cpu", "24", "60", "5400"], [FIX], [BIN_P, "--test-threads=8"]),
]
for label, g, env, leaf in steps:
    rc = subprocess.run([sys.executable, "-B", str(HERE / "guarded.py"), label, *g, *env, "--", *leaf]).returncode
    print(f"STEP {label} rc={rc}", flush=True)
