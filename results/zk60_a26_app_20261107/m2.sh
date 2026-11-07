#!/bin/bash
# Lane A26, measurement job m2 (one guarded gpu-class job): one public post (A24's one-post setting:
# 3 x 10 prover lanes, 3 x 4 verifier lanes) as A/B pairs in both orders (A B B A), then the
# proof-only clock (an 8-post stream with the verifier deferred until the last proof, standing for
# verification on another machine; every receipt is still freshly verified, on its own clock), B then A.
# usage: m2.sh <tag> <B binary>
R=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a010958861d4921eb/results/zk60_a26_app_20261107
A24P=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a010958861d4921eb/results/zk60_a24_app_20261107/posts
A=/Users/victorrielly/zk60-artifacts/proven-media-fast/bin/zk60_classify.a24
TAG=$1; B=$2
O="--lanes 3 --lane-threads 10 --check-lanes 3 --check-threads 4 --witness-gib 16 --keep 0"
S="--lanes 6 --lane-threads 5 --check-lanes 3 --check-threads 4 --witness-gib 16 --keep 0"
P=$R/$TAG.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say "start; B = $B ($(shasum -a 256 $B | cut -c1-16)); free disk $(df -g /Users/victorrielly | tail -1 | awk '{print $4}') GiB"
for run in o1a:$A o1b:$B o2b:$B o2a:$A; do
  t=${run%%:*}; bin=${run#*:}
  /bin/bash $R/stream.sh ${TAG}_$t $A24P/one.json --profile r13 --bin $bin $O > $R/stream_${TAG}_$t.out 2>&1
  say "$t rc=$? $(tail -1 $R/stream_${TAG}_$t.out)"
done
for run in d8b:$B d8a:$A; do
  t=${run%%:*}; bin=${run#*:}
  /bin/bash $R/stream.sh ${TAG}_$t $A24P/stream8.json --profile r13 --bin $bin --defer-check $S > $R/stream_${TAG}_$t.out 2>&1
  say "$t rc=$? $(tail -1 $R/stream_${TAG}_$t.out)"
done
say "all done; free disk $(df -g /Users/victorrielly | tail -1 | awk '{print $4}') GiB"
