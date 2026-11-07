#!/bin/bash
# Lane A26, profile job p1 (one guarded gpu-class job): A24's pinned binary on A24's 8-post public
# stream at A24's app settings (6 x 5 prover, 3 x 4 verifier, 16 GiB witness cache), with each
# server's CPU seconds over the clock and macOS `sample` on both servers for 60 s from 90 s.
# Every receipt freshly verified. Diagnostics: the profile of where the CPU goes.
R=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a010958861d4921eb/results/zk60_a26_app_20261107
A24P=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a010958861d4921eb/results/zk60_a24_app_20261107/posts
A24BIN=/Users/victorrielly/zk60-artifacts/proven-media-fast/bin/zk60_classify.a24
S="--lanes 6 --lane-threads 5 --check-lanes 3 --check-threads 4 --witness-gib 16 --keep 0"
P=$R/p1.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say "start; free disk $(df -g /Users/victorrielly | tail -1 | awk '{print $4}') GiB"
/bin/bash $R/stream.sh p1s8 $A24P/stream8.json --profile r13 --bin $A24BIN $S --sample 90:60 > $R/stream_p1s8.out 2>&1; say "A24 s8 sampled rc=$? $(tail -1 $R/stream_p1s8.out)"
# the first A26 candidate (b1: the verifier's sparse column combination and split-eq public tables)
B1=/Users/victorrielly/zk60-artifacts/proven-media-fast/bin/zk60_classify.a26-b1
/bin/bash $R/stream.sh p1b1 $A24P/stream8.json --profile r13 --bin $B1 $S --sample 90:60 > $R/stream_p1b1.out 2>&1; say "A26 b1 s8 sampled rc=$? $(tail -1 $R/stream_p1b1.out)"
say "all done; free disk $(df -g /Users/victorrielly | tail -1 | awk '{print $4}') GiB"
