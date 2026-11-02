#!/bin/bash
# D59 condition (5) privacy re-check (2026-11-02): the guarded gpu-metal test build of this worktree
# (and, with `check` as $1, the no-feature `cargo check --tests` too). Prints the test binary path.
set -u
R=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-acdb40abef543db2f
G="python3 /Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
L=$R/results/zk60_w16r2_20261101/logs/privacy_recheck
H=$R/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
TAG=${2:-build}
rm -f $L/$TAG.log $L/$TAG.guard.done
if [ "${1:-}" = check ]; then
  CMD="cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib --no-run && cargo check --release --offline --locked --manifest-path $H --lib --tests"
else
  CMD="cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib --no-run"
fi
$G --class build --need-gib 4 --cap-gib 10 --label pr-$TAG --wait-secs 7200 --max-secs 3600 --log $L/$TAG.log --done $L/$TAG.guard.done -- bash -c "$CMD" \
  || { grep -E -A12 '^error' $L/$TAG.log | tail -80; exit 1; }
REL=$(grep -E -o 'target/release/deps/hashline-[0-9a-f]{16}' $L/$TAG.log | tail -1)
[ -n "$REL" ] || { echo "NO TEST BINARY IN THE BUILD LOG"; exit 1; }
B=$R/ops/zkp-mvp/gpu-metal/hashline/$REL
echo "$B" > $L/binary.path
shasum -a 256 $B | tee $L/binary.sha256
grep -c "^warning" $L/$TAG.log
