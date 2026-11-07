#!/bin/bash
# D63 Lean lane L15 (2026-11-07): build hashline's tests and run the TEST-ONLY corpus export
# (private_block/token_io/lean_l15_export_tests.rs: an honest classifier run on the development rung, proved, verified
# by the production verify_classify_run with the run capture's recorder attached; stage OUT-C's LogUp challenges and
# its eight slot records written with the profile facts). Run through run_guarded.py (class cpu).
# usage: export_corpus.sh <corpus path>
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a656d67cb6858d77e
start=$(date +%s)
env LEAN_L15_CORPUS="$1" /opt/homebrew/bin/cargo test --release --offline --locked -j 2 \
  --manifest-path "$WT/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml" --lib lean_l15_export -- --nocapture
rc=$?
echo "rc $rc, $(( $(date +%s) - start )) s"
[ -f "$1" ] && wc -c "$1" && shasum -a 256 "$1"
exit $rc
