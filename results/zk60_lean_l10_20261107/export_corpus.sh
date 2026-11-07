#!/bin/bash
# D63 lane L10 (2026-11-07): build and run the TEST-ONLY export hashline/src/lean_l10_export_tests.rs (a real W16R2
# rung block core: its M, A and H openings, honest and tampered), writing the corpus OUTSIDE the repository (it is
# several MB; the repository takes no file over 1 MB): its size and sha256 are recorded in corpus.sha256 here. Run
# through run_guarded.py (the zk60 resource guard, class cpu).
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a9f0e162e79db6aa4
OUT=$WT/results/zk60_lean_l10_20261107
SCR=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad
export CARGO_TARGET_DIR=$SCR/target-l10
export LEAN_L10_CORPUS=${LEAN_L10_CORPUS:-$SCR/l10/corpus_w16r2.txt}
start=$(date +%s)
/opt/homebrew/bin/cargo test --release --offline --locked -j 2 --manifest-path "$WT/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml" \
  --lib lean_l10_export -- --nocapture
rc=$?
echo "rc $rc, $(( $(date +%s) - start )) s"
if [ -f "$LEAN_L10_CORPUS" ]; then
  ls -la "$LEAN_L10_CORPUS"
  shasum -a 256 "$LEAN_L10_CORPUS" | tee "$OUT/corpus.sha256"
  wc -c < "$LEAN_L10_CORPUS" >> "$OUT/corpus.sha256"
fi
exit $rc
