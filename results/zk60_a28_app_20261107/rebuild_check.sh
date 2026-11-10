#!/bin/bash
# Lane A28 (resumed 2026-11-09): is a candidate binary exactly what the committed tree builds? Forces the hashline
# crate to recompile (touching one source file: its content, and so git, unchanged), rebuilds the release CLI
# with the lane's flags and compares its SHA-256 with the kept candidate's. One guarded build-class job.
# usage: rebuild_check.sh <tag> <candidate binary>
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a6d02411a78ede69c
H=$WT/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
R=$WT/results/zk60_a28_app_20261107
TAG=$1; CAND=$2
P=$R/rebuild_$TAG.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say "start at $(git -C $WT rev-parse --short HEAD); tracked changes under ops/: $(git -C $WT status --short -- ops | wc -l | tr -d ' ')"
say "before: target binary $(shasum -a 256 $WT/ops/zkp-mvp/gpu-metal/hashline/target/release/examples/zk60_classify | cut -c1-16)"
touch $WT/ops/zkp-mvp/gpu-metal/hashline/src/gpu/metal.rs
/opt/homebrew/bin/cargo build --release --offline --locked -j 2 --features gpu-metal --manifest-path $H --example zk60_classify > $R/rebuild_$TAG.log 2>&1
rc=$?
say "release CLI rc=$rc; compiled hashline: $(grep -c 'Compiling hashline' $R/rebuild_$TAG.log)"
a=$(shasum -a 256 $WT/ops/zkp-mvp/gpu-metal/hashline/target/release/examples/zk60_classify | cut -d' ' -f1)
b=$(shasum -a 256 $CAND | cut -d' ' -f1)
say "rebuilt $a"
say "kept    $b ($CAND)"
if [ "$a" = "$b" ]; then say "IDENTICAL: the kept candidate is the committed tree's build"; else say "DIFFERENT"; fi
say "all done"
[ "$a" = "$b" ]
