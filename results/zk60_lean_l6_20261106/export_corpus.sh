#!/bin/bash
# D63 step L6 Lean lane (2026-11-06): build and run the TEST-ONLY corpus export of zkp-core (tests/lean_l6_export.rs),
# writing corpus.txt here. Run through run_guarded.py (the zk60 resource guard, class cpu).
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a18b9cae3877467ba
OUT=$WT/results/zk60_lean_l6_20261106
export CARGO_TARGET_DIR=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/target-l6
export LEAN_L6_CORPUS=$OUT/corpus.txt
start=$(date +%s)
/opt/homebrew/bin/cargo test --release --offline --locked -j 2 --manifest-path "$WT/ops/zkp-mvp/gpu-metal/zkp-core/Cargo.toml" \
  --test lean_l6_export -- --nocapture
rc=$?
echo "rc $rc, $(( $(date +%s) - start )) s"
ls -la "$LEAN_L6_CORPUS" 2>/dev/null
exit $rc
