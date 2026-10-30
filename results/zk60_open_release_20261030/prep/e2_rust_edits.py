#!/usr/bin/env python3
"""E2, Rust side: parametrise the owner-box paths in the reference prover's TEST and
UNPINNED files of a staging tree. Every edit is an exact replacement that must match
the expected number of times (else the script stops and changes nothing further).

Never touches a capture source-pinned file (run_capture.rs OWN_SOURCE_FILES /
SHARED_SOURCE_FILES / CLASSIFY_SOURCE_FILES): privacy gate v23 pins their digests.

Semantics (the same three variables as the Python side):
  ZK60_REPO   the repository root; default = this checkout (the crate's parent dir).
              Lane result folders are $ZK60_REPO/results/<lane>.
  ZK60_MODELS model checkpoints (old /home/victor/models)
  ZK60_ARTIFACTS large outputs kept outside the work tree (old /home/victor/zk60-artifacts)
With ZK60_REPO=/home/victor/IntelligenceRegulation every default string below is
byte-identical to the old literal.

Usage: python3 -I e2_rust_edits.py <staging root>
"""
import sys
from pathlib import Path

ROOT = Path(sys.argv[1])
OLD = "/home/victor/IntelligenceRegulation/"

HELPER_R = '''
/// `$ZK60_REPO/<rel>`: ZK60_REPO is the repository root (default: this
/// checkout, the crate's parent). Lane result folders live under
/// `$ZK60_REPO/results/`.
fn repo_path(rel: &str) -> String {
    let root = std::env::var("ZK60_REPO").unwrap_or_else(|_| concat!(env!("CARGO_MANIFEST_DIR"), "/..").to_string());
    format!("{root}/{rel}")
}
'''

EDITS = [
    # ---- token_io capture tests (all #[ignore]d gate captures)
    ("hashline/src/private_block/token_io/capture_tests.rs", [
        ("fn env_or(k: &str, default: &str) -> String {\n    std::env::var(k).unwrap_or_else(|_| default.to_string())\n}\n",
         "fn env_or(k: &str, default: &str) -> String {\n    std::env::var(k).unwrap_or_else(|_| default.to_string())\n}\n" + HELPER_R, 1),
        ('env_or("TOKEN_IO_R2_EXPORT", "' + OLD + 'results/zk60_1b_calibration_20260929/export/pg_rot1_b4_T32_cal128")',
         'env_or("TOKEN_IO_R2_EXPORT", &repo_path("results/zk60_1b_calibration_20260929/export/pg_rot1_b4_T32_cal128"))', 2),
        ('env_or("TOKEN_IO_R2_INPUTS", "' + OLD + 'results/zk60_token_io_r1_20261017/r2_inputs")',
         'env_or("TOKEN_IO_R2_INPUTS", &repo_path("results/zk60_token_io_r1_20261017/r2_inputs"))', 2),
        ('env_or("HL_PB_TOKEN_EXPORT", "' + OLD + 'results/zk60_fidelity_parity_20261019/exports/llama3_8b_pg_rot1_b7voc0_T32")',
         'env_or("HL_PB_TOKEN_EXPORT", &repo_path("results/zk60_fidelity_parity_20261019/exports/llama3_8b_pg_rot1_b7voc0_T32"))', 1),
    ]),
    ("hashline/src/private_block/token_io/r2_tests.rs", [
        ("fn env_path(k: &str, default: &str) -> std::path::PathBuf {\n    std::path::PathBuf::from(std::env::var(k).unwrap_or_else(|_| default.to_string()))\n}\n",
         "fn env_path(k: &str, default: &str) -> std::path::PathBuf {\n    std::path::PathBuf::from(std::env::var(k).unwrap_or_else(|_| default.to_string()))\n}\n" + HELPER_R, 1),
        ('env_path("TOKEN_IO_R2_EXPORT", "' + OLD + 'results/zk60_1b_calibration_20260929/export/pg_rot1_b4_T32_cal128")',
         'env_path("TOKEN_IO_R2_EXPORT", &repo_path("results/zk60_1b_calibration_20260929/export/pg_rot1_b4_T32_cal128"))', 1),
        ('env_path("TOKEN_IO_R2_INPUTS", "' + OLD + 'results/zk60_token_io_r1_20261017/r2_inputs")',
         'env_path("TOKEN_IO_R2_INPUTS", &repo_path("results/zk60_token_io_r1_20261017/r2_inputs"))', 1),
    ]),
    ("hashline/src/private_block/token_io/r3_tests.rs", [
        ("fn env_path(k: &str, default: &str) -> PathBuf {\n    PathBuf::from(std::env::var(k).unwrap_or_else(|_| default.to_string()))\n}\n",
         "fn env_path(k: &str, default: &str) -> PathBuf {\n    PathBuf::from(std::env::var(k).unwrap_or_else(|_| default.to_string()))\n}\n" + HELPER_R, 1),
        ('env_path("TOKEN_IO_R3_EXPORT", "' + OLD + 'results/zk60_8b_calibration_20261017/export/llama3_8b_pg_rot1_T32")',
         'env_path("TOKEN_IO_R3_EXPORT", &repo_path("results/zk60_8b_calibration_20261017/export/llama3_8b_pg_rot1_T32"))', 1),
    ]),
    # ---- run capture tests: a doc comment and a path-string probe (never created)
    ("hashline/src/private_block/run_capture_tests.rs", [
        ("under `/home/victor/zk60-artifacts/`, as the 125M captures are)",
         "under `$ZK60_ARTIFACTS/`, as the 125M captures are)", 1),
        ('capture_dir_checked("/home/victor/zk60-artifacts/s27-guard-probe")',
         'capture_dir_checked("/nonexistent-zk60-artifacts/s27-guard-probe")', 1),
    ]),
    # ---- the 125M FFN process tests (they loud-skip when the export is absent)
    ("hashline/tests/zk60_gpu_cache.rs", [
        ('const V3_EXPORT_DEFAULT: &str = "/home/victor/wt-uperf3-aa/results/m8b_test/m125_v3_export";\n'
         'const M125_EXPORT_DEFAULT: &str = "' + OLD + 'results/m125_ffn_export_wsl";\n',
         '/// `$ZK60_REPO/<rel>` (ZK60_REPO default: this checkout). The v3 export was\n'
         '/// first read from a lane worktree; the main tree holds the same path.\n'
         'fn repo_path(rel: &str) -> String {\n'
         '    let root = std::env::var("ZK60_REPO").unwrap_or_else(|_| concat!(env!("CARGO_MANIFEST_DIR"), "/..").to_string());\n'
         '    format!("{root}/{rel}")\n'
         '}\n', 1),
        ('std::env::var("HL_EXPORT_DIR").unwrap_or_else(|_| V3_EXPORT_DEFAULT.to_string())',
         'std::env::var("HL_EXPORT_DIR").unwrap_or_else(|_| repo_path("results/m8b_test/m125_v3_export"))', 2),
        ('std::env::var("M125_EXPORT_DIR").unwrap_or_else(|_| M125_EXPORT_DEFAULT.to_string())',
         'std::env::var("M125_EXPORT_DIR").unwrap_or_else(|_| repo_path("results/m125_ffn_export_wsl"))', 1),
    ]),
    # ---- unpinned production default (the old 125M FFN CLI; M125_EXPORT_DIR still wins)
    ("hashline/src/export.rs", [
        ('    PathBuf::from("' + OLD + 'results/m125_ffn_export_wsl")\n',
         '    let repo = std::env::var("ZK60_REPO").unwrap_or_else(|_| concat!(env!("CARGO_MANIFEST_DIR"), "/..").to_string());\n'
         '    PathBuf::from(repo).join("results/m125_ffn_export_wsl")\n', 1),
    ]),
    # ---- build notes (comments only)
    ("hashline/Cargo.toml", [
        ("# Build: CUDA_ROOT=/home/victor/cuda-root LD_LIBRARY_PATH=<driver+nvrtc>",
         "# Build: CUDA_ROOT=<your CUDA toolkit root> LD_LIBRARY_PATH=<driver+nvrtc>", 1),
    ]),
    ("zkmatrix-rs/Cargo.toml", [
        ("# (this box: /home/victor/cuda-root, see PROGRESS_UPERF2.md round 6).",
         "# (the development box used a user-local toolkit root, CUDA_ROOT=<toolkit root>).", 1),
    ]),
]

PINNED_NEVER_EDIT = {
    "hashline/src/private_block/tied_tables/derive.rs",
    "hashline/src/private_block/trained_accuracy.rs",
    "hashline/src/private_block/run_capture.rs",
}


def main():
    done = []
    for rel, reps in EDITS:
        assert rel not in PINNED_NEVER_EDIT, rel
        p = ROOT / rel
        s = p.read_text()
        for old, new, n in reps:
            c = s.count(old)
            if c != n:
                sys.exit(f"{rel}: expected {n} match(es), found {c}: {old[:80]!r}")
            s = s.replace(old, new)
        p.write_text(s)
        done.append(rel)
    print("edited", len(done), "files:", *done, sep="\n  ")


if __name__ == "__main__":
    main()
