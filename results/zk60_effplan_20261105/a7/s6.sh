#!/bin/bash
# A7 stage 6: stage 5 with the ARM ORDER REVERSED (per-thread first in every pass), to separate the queue's effect on
# the stream from the order of the arms. 5 interleaved passes per arm: the proof-only fork run and a 4-request stream,
# every receipt verified after the clock. Same binary. One guarded job, class gpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a31903453c5c4056a
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$W/results/zk60_effplan_20261105/a7
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
D=private_block::run::fork::tests::d55_ab_one_request_serial_against_forks
P=$O/s6.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=1 HL_D55_GPU_AB=thread+spin,shared+spin HL_D55_AB_PASSES=5 HL_D55_AB_PIPE=4 $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/s6_d55_stream_reversed.log 2>&1; say "d55 stream A/B, order reversed rc=$?"
grep -E "^D55-AB SUMMARY|^D55-AB GPU-AB" $O/s6_d55_stream_reversed.log >> $P
say "all done"
