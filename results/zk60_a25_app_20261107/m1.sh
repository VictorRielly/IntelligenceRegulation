#!/bin/bash
# Lane A25, measurement job m1 (one guarded gpu-class job): two A/B pairs of an 8-post public stream,
# W16R2 development profile (this binary, --dev-w16r2-public-content-only) against A24's R13 fast path
# (A24's pinned binary), alternating order (W R R W), A24's app settings (6 x 5 prover, 3 x 4 verifier,
# 16 GiB witness cache). Every receipt freshly verified (ZK60_THROUGHPUT_TARGET's clock).
R=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a894d1898cebc946c/results/zk60_a25_app_20261107
A24P=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a894d1898cebc946c/results/zk60_a24_app_20261107/posts
A24BIN=/Users/victorrielly/zk60-artifacts/proven-media-fast/bin/zk60_classify.a24
S="--lanes 6 --lane-threads 5 --check-lanes 3 --check-threads 4 --witness-gib 16 --keep 0"
P=$R/m1.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say "start; free disk $(df -g /Users/victorrielly | tail -1 | awk '{print $4}') GiB"
/bin/bash $R/stream.sh s8w_a $A24P/stream8.json --profile w16r2 $S > $R/stream_s8w_a.out 2>&1; say "W16R2 a rc=$? $(tail -1 $R/stream_s8w_a.out)"
/bin/bash $R/stream.sh s8r_a $A24P/stream8.json --profile r13 --bin $A24BIN $S > $R/stream_s8r_a.out 2>&1; say "R13 a rc=$? $(tail -1 $R/stream_s8r_a.out)"
/bin/bash $R/stream.sh s8r_b $A24P/stream8.json --profile r13 --bin $A24BIN $S > $R/stream_s8r_b.out 2>&1; say "R13 b rc=$? $(tail -1 $R/stream_s8r_b.out)"
/bin/bash $R/stream.sh s8w_b $A24P/stream8.json --profile w16r2 $S > $R/stream_s8w_b.out 2>&1; say "W16R2 b rc=$? $(tail -1 $R/stream_s8w_b.out)"
say "all done; free disk $(df -g /Users/victorrielly | tail -1 | awk '{print $4}') GiB"
