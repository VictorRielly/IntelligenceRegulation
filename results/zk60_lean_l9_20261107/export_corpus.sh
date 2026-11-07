#!/bin/bash
# D63 step L9 Lean lane (2026-11-07): the W16R2 rung block's frame and its transcript challenges, exported by the
# TEST-ONLY hashline test `lean_l9_export_the_w16r2_rung_block` (src/private_block/lean_l9_export_tests.rs). Run
# through run_guarded.py (the zk60 resource guard, class cpu). Writes OUT/corpus.txt (committed) and
# OUT/fork_frame.bin (several MB: NOT committed; this script regenerates it byte for byte, its BLAKE3 is in corpus.txt).
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-abdecaa028b7cbdaf
OUT=$WT/results/zk60_lean_l9_20261107
export L9_OUT=$OUT
/opt/homebrew/bin/cargo test --release --offline --locked -j 2 \
  --manifest-path "$WT/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml" --lib \
  lean_l9_export_the_w16r2_rung_block -- --nocapture --test-threads 1
rc=$?
echo "cargo rc $rc"
ls -l "$OUT/corpus.txt" "$OUT/fork_frame.bin" 2>&1
exit $rc
