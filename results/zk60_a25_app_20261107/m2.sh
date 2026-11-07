#!/bin/bash
# Lane A25, measurement job m2 (one guarded gpu-class job): one public post (3 x 10 prover lanes, A24's
# one-post setting) as an A/B pair in both orders (R W W R), then the proof-only clock: an 8-post stream
# with the verifier deferred until the last proof (standing for verification on another machine), W16R2
# then R13. Every receipt is still freshly verified.
R=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a894d1898cebc946c/results/zk60_a25_app_20261107
A24P=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a894d1898cebc946c/results/zk60_a24_app_20261107/posts
A24BIN=/Users/victorrielly/zk60-artifacts/proven-media-fast/bin/zk60_classify.a24
O="--lanes 3 --lane-threads 10 --check-lanes 3 --check-threads 4 --witness-gib 16 --keep 0"
S="--lanes 6 --lane-threads 5 --check-lanes 3 --check-threads 4 --witness-gib 16 --keep 0"
P=$R/m2.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say "start; free disk $(df -g /Users/victorrielly | tail -1 | awk '{print $4}') GiB"
/bin/bash $R/stream.sh o1r_a $A24P/one.json --profile r13 --bin $A24BIN $O > $R/stream_o1r_a.out 2>&1; say "one R13 a rc=$? $(tail -1 $R/stream_o1r_a.out)"
/bin/bash $R/stream.sh o1w_a $A24P/one.json --profile w16r2 $O > $R/stream_o1w_a.out 2>&1; say "one W16R2 a rc=$? $(tail -1 $R/stream_o1w_a.out)"
/bin/bash $R/stream.sh o1w_b $A24P/one.json --profile w16r2 $O > $R/stream_o1w_b.out 2>&1; say "one W16R2 b rc=$? $(tail -1 $R/stream_o1w_b.out)"
/bin/bash $R/stream.sh o1r_b $A24P/one.json --profile r13 --bin $A24BIN $O > $R/stream_o1r_b.out 2>&1; say "one R13 b rc=$? $(tail -1 $R/stream_o1r_b.out)"
/bin/bash $R/stream.sh d8w $A24P/stream8.json --profile w16r2 --defer-check $S > $R/stream_d8w.out 2>&1; say "deferred W16R2 rc=$? $(tail -1 $R/stream_d8w.out)"
/bin/bash $R/stream.sh d8r $A24P/stream8.json --profile r13 --bin $A24BIN --defer-check $S > $R/stream_d8r.out 2>&1; say "deferred R13 rc=$? $(tail -1 $R/stream_d8r.out)"
say "all done; free disk $(df -g /Users/victorrielly | tail -1 | awk '{print $4}') GiB"
