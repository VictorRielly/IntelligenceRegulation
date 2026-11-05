#!/bin/bash
# A7 stage 2: build; the A6 census (CPU only: per device slot, the declared and attained degrees and the multiplies of
# one point); then the D55 harness with the GPU timeline on and an in-process, interleaved GPU-policy A/B over 3 passes
# at N = 6 and 8: the one shared queue (pre-A7) against one queue per thread, each thread's wait spinning, blocking or
# spinning 200 us then blocking, and the opening's row fold on the device. One guarded job, class gpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a31903453c5c4056a
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$W/results/zk60_effplan_20261105/a7
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
D=private_block::run::fork::tests::d55_ab_one_request_serial_against_forks
P=$O/s2.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$C --no-run > $O/s2_build.log 2>&1; say "build rc=$?"
$C private_block::range16_tests::effplan_a6_census_of_the_device_slots -- --ignored --exact --nocapture --test-threads=1 > $O/s2_census.log 2>&1; say "a6 census rc=$?"
env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6,8 HL_D55_PASSES=1 HL_D55_AB_PASSES=3 HL_D55_TIMELINE=1 HL_D55_GPU_AB=shared+spin,thread+spin,thread+block,thread+spin200,thread+spin+devfold $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/s2_d55.log 2>&1; say "d55 GPU-policy A/B rc=$?"
grep -E "^D55-AB SUMMARY|^D55-AB GPU-AB|^D55-AB A7 CPU" $O/s2_d55.log >> $P
say "all done"
