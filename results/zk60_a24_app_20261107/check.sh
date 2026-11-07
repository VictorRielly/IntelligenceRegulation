#!/bin/bash
# Lane A24: cargo check (lib + example + tests) of this worktree's hashline, gpu-metal on.
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a5090f993c1401215
H=$WT/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
R=$WT/results/zk60_a24_app_20261107
TAG=${1:-c1}
/opt/homebrew/bin/cargo check --offline --locked -j 2 --features gpu-metal --manifest-path $H --example zk60_classify --tests > $R/check_$TAG.log 2>&1
rc=$?
echo "check rc=$rc" >> $R/check_$TAG.log
exit $rc
