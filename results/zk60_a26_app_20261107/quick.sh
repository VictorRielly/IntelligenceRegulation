#!/bin/bash
# Lane A26 quick check (one guarded build-class job): the release CLI, then zkp-core's lib suite.
# usage: quick.sh <tag>
set -u
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a010958861d4921eb
H=$WT/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
Z=$WT/ops/zkp-mvp/gpu-metal/zkp-core/Cargo.toml
R=$WT/results/zk60_a26_app_20261107
TAG=${1:-q1}
P=$R/quick_$TAG.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
/opt/homebrew/bin/cargo build --release --offline --locked -j 2 --features gpu-metal --manifest-path $H --example zk60_classify > $R/quick_${TAG}_build.log 2>&1; rc=$?; say "release CLI rc=$rc"
if [ $rc -ne 0 ]; then grep -E "^error" -A 14 $R/quick_${TAG}_build.log | head -80 >> $P; say "all done (build failed)"; exit 1; fi
say "zk60_classify sha256 $(shasum -a 256 $WT/ops/zkp-mvp/gpu-metal/hashline/target/release/examples/zk60_classify | cut -d' ' -f1)"
/opt/homebrew/bin/cargo test --release --offline --locked -j 2 --manifest-path $Z --lib > $R/quick_${TAG}_zkpcore.log 2>&1; say "zkp-core lib tests rc=$?"
grep -E "a26|test result" $R/quick_${TAG}_zkpcore.log >> $P
say "all done"
