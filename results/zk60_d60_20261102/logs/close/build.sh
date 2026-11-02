#!/bin/bash
# D60 review closure: one guarded build step: the gpu-metal test build and the no-feature `cargo check --release
# --lib --tests` (warnings counted over this log, the D60 chain's method: baseline 133), then the release CLI
# example in its own log. Usage: build.sh <stem>
set -u
R=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a2e328baa581cb5b0
G="python3 /Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
L=$R/results/zk60_d60_20261102/logs/close
H=$R/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
S=${1:-build}
export ZK60_GUARD_POLL_SECS=0.05
rm -f $L/$S.log $L/$S.guard.done $L/$S-cli.log $L/$S-cli.guard.done
$G --class build --need-gib 4 --cap-gib 10 --label d60close-$S --wait-secs 7200 --max-secs 3600 --log $L/$S.log --done $L/$S.guard.done -- \
  bash -c "cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib --no-run && cargo check --release --offline --locked --manifest-path $H --lib --tests" \
  || { grep -E -A14 '^error' $L/$S.log | head -80; exit 1; }
echo "warnings (whole log, the chain's method): $(grep -c '^warning' $L/$S.log)"
echo "Finished lines: $(grep -c 'Finished' $L/$S.log)"
REL=$(grep -E -o 'target/release/deps/hashline-[0-9a-f]{16}' $L/$S.log | tail -1)
echo "test binary: $R/ops/zkp-mvp/gpu-metal/hashline/$REL"
sleep 2
$G --class build --need-gib 4 --cap-gib 10 --label d60close-$S-cli --wait-secs 7200 --max-secs 3600 --log $L/$S-cli.log --done $L/$S-cli.guard.done -- \
  cargo build --release --offline --locked --features gpu-metal --manifest-path $H --example zk60_trained_block \
  || { grep -E -A14 '^error' $L/$S-cli.log | head -80; exit 1; }
shasum -a 256 $R/ops/zkp-mvp/gpu-metal/hashline/target/release/examples/zk60_trained_block
