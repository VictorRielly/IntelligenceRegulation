#!/bin/bash
# Lane A27 (from A26): build the classifier CLI (release, gpu-metal) from this worktree.
# usage: build.sh <tag>   (logs into results/zk60_a27_app_20261107/build_<tag>.log)
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a6ef8e7c158543247
H=$WT/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
R=$WT/results/zk60_a27_app_20261107
TAG=${1:-base}
/opt/homebrew/bin/cargo build --release --offline --locked -j 2 --features gpu-metal --manifest-path $H \
  --example zk60_classify > $R/build_$TAG.log 2>&1
rc=$?
echo "build rc=$rc" >> $R/build_$TAG.log
exit $rc
