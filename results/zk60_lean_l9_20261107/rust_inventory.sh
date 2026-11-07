#!/bin/bash
# D63 step L9 Lean lane (2026-11-07): the hashline source-inventory tests that a new test file under
# src/private_block/ must pass (s25_tests.rs: r19b, every .rs file on the module path or a named test-only file), and
# the W16R2 tests module that declares the export (its harness unchanged). Run through run_guarded.py.
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-abdecaa028b7cbdaf
/opt/homebrew/bin/cargo test --release --offline --locked -j 2 \
  --manifest-path "$WT/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml" --lib r19b -- --test-threads 2
rc=$?
echo "cargo rc $rc"
exit $rc
