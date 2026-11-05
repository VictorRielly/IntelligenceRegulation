#!/bin/bash
# A7 stage 1, the MEASUREMENT: build; the queue byte test (six concurrent seeded W16R2 rung proofs, on the one shared
# queue and on one queue per thread, each equal to the CPU digest and the golden; plus a check of the timeline's clock);
# then the D55 harness with the GPU timeline on (HL_D55_TIMELINE=1) and an in-process queue A/B (shared, thread).
# One guarded job, class gpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a31903453c5c4056a
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$W/results/zk60_effplan_20261105/a7
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
D=private_block::run::fork::tests::d55_ab_one_request_serial_against_forks
P=$O/s1.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$C --no-run > $O/s1_build.log 2>&1; say "build rc=$?"
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::a7_w16r2_rung_digests_on_six_threads_at_one_and_at_six_queues -- --ignored --exact --nocapture --test-threads=1 > $O/s1_queues.log 2>&1; say "a7 queue byte test rc=$?"
env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=2 HL_D55_TIMELINE=1 HL_D55_QUEUE_AB=shared,thread $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/s1_d55.log 2>&1; say "d55 timeline + queue A/B rc=$?"
grep -E "^D55-AB SUMMARY|^D55-AB QUEUES|^D55-AB A7|window|idle gaps" $O/s1_d55.log >> $P
say "all done"
