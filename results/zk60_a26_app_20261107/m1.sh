#!/bin/bash
# Lane A26, measurement job m1 (one guarded gpu-class job): A/B pairs of A24's 8-post public stream,
# A24's pinned binary (A) against this lane's candidate (B), alternating order (A B B A), at A24's
# app settings (6 x 5 prover, 3 x 4 verifier, 16 GiB witness cache). Every receipt freshly verified
# (ZK60_THROUGHPUT_TARGET's clock); each server's CPU seconds over the clock.
# usage: m1.sh <tag> <B binary>
R=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a010958861d4921eb/results/zk60_a26_app_20261107
A24P=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a010958861d4921eb/results/zk60_a24_app_20261107/posts
A=/Users/victorrielly/zk60-artifacts/proven-media-fast/bin/zk60_classify.a24
TAG=$1; B=$2
S="--lanes 6 --lane-threads 5 --check-lanes 3 --check-threads 4 --witness-gib 16 --keep 0"
P=$R/$TAG.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say "start; B = $B ($(shasum -a 256 $B | cut -c1-16)); free disk $(df -g /Users/victorrielly | tail -1 | awk '{print $4}') GiB"
for run in a1:$A b1:$B b2:$B a2:$A; do
  t=${run%%:*}; bin=${run#*:}
  /bin/bash $R/stream.sh ${TAG}_$t $A24P/stream8.json --profile r13 --bin $bin $S > $R/stream_${TAG}_$t.out 2>&1
  say "$t rc=$? $(tail -1 $R/stream_${TAG}_$t.out)"
done
say "all done; free disk $(df -g /Users/victorrielly | tail -1 | awk '{print $4}') GiB"
