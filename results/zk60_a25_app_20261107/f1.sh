#!/bin/bash
# Lane A25, the first real-model job (one guarded gpu-class job): one public post through the servers at
# the W16R2 development profile, the same post at R13 with this binary (no switch), then the negative
# controls on both receipts.
R=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a894d1898cebc946c/results/zk60_a25_app_20261107
A24P=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a894d1898cebc946c/results/zk60_a24_app_20261107/posts
P=$R/f1.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
/bin/bash $R/stream.sh w1 $A24P/one.json --profile w16r2 --keep 1 --lanes 3 --lane-threads 10 > $R/stream_w1.out 2>&1; say "W16R2 one post rc=$? $(tail -1 $R/stream_w1.out)"
/bin/bash $R/stream.sh r1 $A24P/one.json --profile r13 --keep 1 --lanes 3 --lane-threads 10 > $R/stream_r1.out 2>&1; say "R13 (this binary) one post rc=$? $(tail -1 $R/stream_r1.out)"
/bin/bash $R/negctl.sh w1 r1; say "negctl rc=$?"
say "all done"
