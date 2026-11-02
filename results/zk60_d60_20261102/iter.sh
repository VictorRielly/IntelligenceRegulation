#!/bin/bash
# D60 iteration helper: build the gpu-metal test binary (guarded), then run the given test filters
# (guarded, cpu class). Usage: iter.sh <log-stem> [test filters...]. Logs in logs/iter/.
set -u
R=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a13712d1ade4dcee1
G="python3 /Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
L=$R/results/zk60_d60_20261102/logs/iter
H=$R/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
F=/Users/victorrielly/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
export ZK60_GUARD_POLL_SECS=0.05
mkdir -p $L
S=$1; shift
rm -f $L/$S.build.log $L/$S.build.done $L/$S.test.log $L/$S.test.done
$G --class build --need-gib 4 --cap-gib 10 --label d60-$S-build --wait-secs 7200 --max-secs 3600 --log $L/$S.build.log --done $L/$S.build.done -- \
  cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib --no-run || { grep -E -A14 '^error' $L/$S.build.log | head -120; exit 1; }
REL=$(grep -E -o 'target/release/deps/hashline-[0-9a-f]{16}' $L/$S.build.log | tail -1)
B=$R/ops/zkp-mvp/gpu-metal/hashline/$REL
echo "B=$B"
[ $# -eq 0 ] && exit 0
$G --class cpu --need-gib 8 --cap-gib 40 --label d60-$S-test --wait-secs 7200 --max-secs 3000 --log $L/$S.test.log --done $L/$S.test.done -- \
  env HL_R13_LOADER_FIXTURES=$F $B "$@"
grep -h "test result\|FAILED\|panicked" $L/$S.test.log | head -40
