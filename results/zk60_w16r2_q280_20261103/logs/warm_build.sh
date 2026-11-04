#!/bin/bash
# Warm the dependency build of this worktree's gpu-metal hashline tree (a cold target dir), guarded.
# A hashline compile error here is harmless: the point is the dependency artifacts. The real build is
# step 1 of q280_targeted.sh.
set -u
export ZK60_GUARD_POLL_SECS=0.5
R=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a7e40cbdbbf3f1b5d
G="python3 /Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
L=$R/results/zk60_w16r2_q280_20261103/logs
H=$R/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
$G --class build --need-gib 6 --cap-gib 16 --label q280-warm-build --wait-secs 28800 --max-secs 5400 --log $L/warm_build.log --done $L/warm_build.guard.done -- \
  bash -c "cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib --no-run -j 8"
echo "warm build exit $?"
