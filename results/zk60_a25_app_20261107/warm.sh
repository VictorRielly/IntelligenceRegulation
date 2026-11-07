#!/bin/bash
# Lane A25: warm this worktree's target dir at the base tree (release example + release test build).
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a894d1898cebc946c
H=$WT/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
R=$WT/results/zk60_a25_app_20261107
/bin/bash $R/build.sh base; echo "example rc=$?" > $R/warm.progress
/opt/homebrew/bin/cargo test --release --offline --locked -j 2 --features gpu-metal --manifest-path $H --lib --no-run > $R/warm_test.log 2>&1
echo "test build rc=$?" >> $R/warm.progress
shasum -a 256 $WT/ops/zkp-mvp/gpu-metal/hashline/target/release/examples/zk60_classify >> $R/warm.progress
