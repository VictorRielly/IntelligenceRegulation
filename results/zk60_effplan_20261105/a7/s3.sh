#!/bin/bash
# A7 stage 3, ACCEPTANCE on the final tree (per-thread queues the default): build; a no-feature `cargo check --tests`;
# the full lib suite (expect only the known three failures); the A7 queue byte test; the W16R2 rung golden and the six
# post-F12 trained digests under HL_GPU_REQUIRED=1; then the D55 harness three times, sealed one request and a
# 4-request stream: BEFORE (HL_METAL_QUEUES=shared, the pre-A7 queue), AFTER (the new default), and an informational
# arm with HL_METAL_SPIN_US=200. One guarded job, class gpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a31903453c5c4056a
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$W/results/zk60_effplan_20261105/a7
F=/Users/victorrielly/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
T=private_block::slot_ir::accuracy::tests
D=private_block::run::fork::tests::d55_ab_one_request_serial_against_forks
E="HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=2 HL_D55_SEALED=1 HL_D55_PIPE=4"
P=$O/s3.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$C --no-run > $O/s3_build.log 2>&1; say "build rc=$?"
/opt/homebrew/bin/cargo check --tests --offline --locked --manifest-path $H > $O/s3_check_nometal.log 2>&1; say "no-feature cargo check --tests rc=$?"
env HL_R13_LOADER_FIXTURES=$F $C -- --test-threads=8 > $O/s3_full.log 2>&1; say "full lib suite rc=$? (expect failures: exactly the known three)"
grep -E "^test result|^    [a-z_:0-9]+$" $O/s3_full.log | tail -8 >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::a7_w16r2_rung_digests_on_six_threads_at_one_and_at_six_queues -- --ignored --exact --nocapture --test-threads=1 > $O/s3_queues.log 2>&1; say "a7 queue byte test rc=$?"
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::w16r2_rung_cpu_and_metal_digests_equal_the_golden -- --ignored --exact --nocapture --test-threads=1 > $O/s3_r2rung.log 2>&1; say "w16r2 rung golden rc=$?"
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 HL_M4_PHASES=1 HL_M4_WARM_PASSES=1 HL_M4_PROFILES=R13_SHIELD_T128_H24,R13_8B_T128_H24,W16_SHIELD_T128_H24,W16_8B_T128_H24,W16R2_SHIELD_T128_H24,W16R2_8B_T128_H24 $C $T::m4_trained_accuracy_block_cpu_and_metal_digests_and_times -- --ignored --exact --nocapture --test-threads=1 > $O/s3_trained.log 2>&1; say "trained digests rc=$?"
for d in 5a6193d3 f590b01f 79f987ef a8258241 0e88d84f 90003b76; do
  if grep -q "$d" $O/s3_trained.log; then say "digest $d present"; else say "DIGEST $d MISSING"; fi
done
env $E HL_METAL_QUEUES=shared $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/s3_d55_before.log 2>&1; say "d55 BEFORE (HL_METAL_QUEUES=shared) rc=$?"
grep -E "sealing pass|^D55-AB SUMMARY|^D55-AB PIPE" $O/s3_d55_before.log >> $P
env $E $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/s3_d55_after.log 2>&1; say "d55 AFTER (per-thread queues, the default) rc=$?"
grep -E "sealing pass|^D55-AB SUMMARY|^D55-AB PIPE" $O/s3_d55_after.log >> $P
env $E HL_METAL_SPIN_US=200 $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/s3_d55_spin200.log 2>&1; say "d55 per-thread queues + HL_METAL_SPIN_US=200 rc=$?"
grep -E "sealing pass|^D55-AB SUMMARY|^D55-AB PIPE" $O/s3_d55_spin200.log >> $P
say "all done"
