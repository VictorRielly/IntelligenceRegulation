#!/bin/bash
# D63 step L13 Lean lane (2026-11-07): build hashline's tests and run the TEST-ONLY layout export
# (private_block/lean_l13_export_tests.rs: the W16R2 layout facts at the rung, Shieldstral T128 and 8B T128 shapes).
# Run through run_guarded.py (class cpu).
# usage: export_l13.sh <corpus path>
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a30bf89c063c9ac1c
start=$(date +%s)
env LEAN_L13_CORPUS="$1" /opt/homebrew/bin/cargo test --release --offline --locked -j 2 \
  --manifest-path "$WT/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml" --lib lean_l13_export -- --nocapture
rc=$?
echo "rc $rc, $(( $(date +%s) - start )) s"
[ -f "$1" ] && wc -c "$1" && shasum -a 256 "$1"
exit $rc
