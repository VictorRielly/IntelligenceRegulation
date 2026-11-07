#!/bin/bash
# D63 Lean lane L18 (2026-11-07): build hashline's tests and run the TEST-ONLY framing export
# (src/lean_l18_export_tests.rs, a child of the test-only private_block/token_io/classify_capture_tests.rs: an honest
# classifier run on the development rung with two blocks, proved, verified by the production verify_classify_run, and
# verify_classify_run_with's loop replayed beside it with the production pieces, recording every segment boundary's
# transcript and tags, every block's framing and the claims carried). Run through run_guarded.py (class cpu).
# usage: export_corpus.sh <corpus path>
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a7ec794744dd611b8
start=$(date +%s)
env LEAN_L18_CORPUS="$1" /opt/homebrew/bin/cargo test --release --offline --locked -j 2 \
  --manifest-path "$WT/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml" --lib lean_l18_export -- --nocapture
rc=$?
echo "rc $rc, $(( $(date +%s) - start )) s"
[ -f "$1" ] && wc -c "$1" && shasum -a 256 "$1"
exit $rc
