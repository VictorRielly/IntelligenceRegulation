#!/bin/bash
# TS / CENSUS / bases lane (2026-11-02): the gpu-metal release test build of this worktree (and the no-feature
# check when $1 = full), guarded (build class); writes logs/binary.path and logs/binary.sha256.
# (privacy_gate_r26/build.sh with this worktree's paths.)  The bundles are written on the CPU (HL_GPU unset).
set -u
R=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-ad5119ba9083f7dc7
G="python3 /Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
L=$R/results/zk60_d60_20261102/privacy_gate_tsbases/logs
H=$R/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
TAG=${2:-build}
rm -f $L/$TAG.log $L/$TAG.guard.done
if [ "${1:-}" = full ]; then
  CMD="cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib --no-run && cargo check --release --offline --locked --manifest-path $H --lib --tests"
else
  CMD="cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib --no-run"
fi
$G --class build --need-gib 4 --cap-gib 12 --label tsb-$TAG --wait-secs 7200 --max-secs 3600 --log $L/$TAG.log --done $L/$TAG.guard.done -- bash -c "$CMD"
rc=$?
grep -E -A12 '^error' $L/$TAG.log | head -60
echo "warnings: $(grep -c '^warning' $L/$TAG.log)"
REL=$(grep -E -o 'target/release/deps/hashline-[0-9a-f]{16}' $L/$TAG.log | tail -1)
if [ $rc = 0 ] && [ -n "$REL" ]; then
  B=$R/ops/zkp-mvp/gpu-metal/hashline/$REL
  echo "$B" > $L/binary.path
  shasum -a 256 $B | tee $L/binary.sha256
fi
exit $rc
