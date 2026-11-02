#!/bin/bash
# W16R2 review closure: one iteration (guarded build, then the changed tests with their output). $1 = stem.
set -u
R=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a212d1a7c4f5d315b
G="python3 /Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
L=$R/results/zk60_w16r2_20261101/logs/close
H=$R/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
F=/Users/victorrielly/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
S=${1:-iter}
rm -f $L/${S}_build.log $L/${S}_tests.log
$G --class build --need-gib 4 --cap-gib 10 --label w16r2-close-iter-build --wait-secs 7200 --max-secs 3600 --log $L/${S}_build.log --done $L/${S}_build.done -- \
  cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib --no-run || { grep -E -A12 '^error' $L/${S}_build.log | head -120; exit 1; }
REL=$(grep -E -o 'target/release/deps/hashline-[0-9a-f]{16}' $L/${S}_build.log | tail -1)
B=$R/ops/zkp-mvp/gpu-metal/hashline/$REL
echo "B=$B"
$G --class cpu --need-gib 8 --cap-gib 40 --label w16r2-close-iter-tests --wait-secs 7200 --max-secs 3000 --log $L/${S}_tests.log --done $L/${S}_tests.done -- \
  env HL_R13_LOADER_FIXTURES=$F $B w16r2_tests:: range16_tests::w16_limbs s33_tests:: --nocapture --test-threads=4
grep -h "test result\|FAILED\|panicked" $L/${S}_tests.log | head -40
