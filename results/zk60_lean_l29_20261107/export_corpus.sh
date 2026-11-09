#!/bin/bash
# D63 Lean lane L29 (2026-11-07): build hashline's tests and run the TEST-ONLY export src/lean_l29_export_tests.rs (a
# child of the test-only private_block/token_io/classify_capture_tests.rs): an honest classifier run on the development
# rung (one block), proved, verified by the production verify_classify_run, and stage IN-C's and stage OUT-C's verifiers
# replayed with the production pieces (each replay asserted to end on the production verifier's transcript). Writes the
# text corpus here (corpus.txt) and the two stage segments' bytes OUTSIDE the repository (each over 1 MB; the repository
# takes no file over 1 MB): their sizes and sha256 are recorded in segments.sha256 here. Run through run_guarded.py
# (the zk60 resource guard, class cpu). The receipt is fresh-entropy: every run writes a different corpus.
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a5e8655cfe4c9f794
OUT=$WT/results/zk60_lean_l29_20261107
SCR=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad
mkdir -p "$SCR/l29"
export CARGO_TARGET_DIR=$SCR/target-l29
export LEAN_L29_CORPUS=$OUT/corpus.txt
export LEAN_L29_SEG_IN=$SCR/l29/l29_seg_in.bin
export LEAN_L29_SEG_OUT=$SCR/l29/l29_seg_out.bin
start=$(date +%s)
/opt/homebrew/bin/cargo test --release --offline --locked -j 2 --manifest-path "$WT/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml" \
  --lib lean_l29_export -- --nocapture
rc=$?
echo "rc $rc, $(( $(date +%s) - start )) s"
if [ -f "$LEAN_L29_CORPUS" ]; then
  wc -c "$LEAN_L29_CORPUS"
  shasum -a 256 "$LEAN_L29_CORPUS" "$LEAN_L29_SEG_IN" "$LEAN_L29_SEG_OUT" | tee "$OUT/segments.sha256"
  wc -c "$LEAN_L29_SEG_IN" "$LEAN_L29_SEG_OUT" | tee -a "$OUT/segments.sha256"
fi
exit $rc
