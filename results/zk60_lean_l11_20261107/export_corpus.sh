#!/bin/bash
# D63 step L11 Lean lane (2026-11-07): build hashline's tests and run the TEST-ONLY corpus export
# (private_block/lean_l11_export_tests.rs: a real W16R2 rung block receipt, proved, verified by the production
# verify_core, then every slot's verify arithmetic recomputed and written). Run through run_guarded.py (class cpu).
# usage: export_corpus.sh <corpus path>
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a7b7bd2255186ea2f
start=$(date +%s)
env LEAN_L11_CORPUS="$1" /opt/homebrew/bin/cargo test --release --offline --locked -j 2 \
  --manifest-path "$WT/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml" --lib lean_l11_export -- --nocapture
rc=$?
echo "rc $rc, $(( $(date +%s) - start )) s"
[ -f "$1" ] && wc -c "$1" && shasum -a 256 "$1"
exit $rc
