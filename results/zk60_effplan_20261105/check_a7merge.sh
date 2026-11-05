#!/bin/bash
# Efficiency plan A7, merged into perf on top of A5 (requant shift form): acceptance on the MERGED tree. Build; a
# no-feature `cargo check --tests`; the requant tests (A5); the full lib suite (expect only the known three failures);
# the A7 queue byte test (shared and per-thread queues); the W16R2 rung golden and the six post-F12 trained digests
# under HL_GPU_REQUIRED=1; the D55 harness on the default (sealed one request and a 4-request stream). One guarded job,
# class gpu.
set -u
H=/Users/victorrielly/IntelligenceRegulation/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=/Users/victorrielly/IntelligenceRegulation/results/zk60_effplan_20261105
F=/Users/victorrielly/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
T=private_block::slot_ir::accuracy::tests
D=private_block::run::fork::tests::d55_ab_one_request_serial_against_forks
P=$O/a7merge.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$C --no-run > $O/a7merge_build.log 2>&1; say "build rc=$?"
/opt/homebrew/bin/cargo check --tests --offline --locked --manifest-path $H > $O/a7merge_check_nometal.log 2>&1; say "no-feature cargo check --tests rc=$?"
$C private_block::accuracy::tests:: > $O/a7merge_requant_tests.log 2>&1; say "requant tests rc=$? $(grep -E '^test result' $O/a7merge_requant_tests.log | head -1)"
env HL_R13_LOADER_FIXTURES=$F $C -- --test-threads=8 > $O/a7merge_full.log 2>&1; say "full lib suite rc=$? (expect failures: exactly the known three)"
grep -E "^test result|^    [a-z_:0-9]+$" $O/a7merge_full.log | tail -8 >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::a7_w16r2_rung_digests_on_six_threads_at_one_and_at_six_queues -- --ignored --exact --nocapture --test-threads=1 > $O/a7merge_queues.log 2>&1; say "a7 queue byte test rc=$?"
grep -E "A7-QUEUES W16R2" $O/a7merge_queues.log | cut -c1-220 >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::w16r2_rung_cpu_and_metal_digests_equal_the_golden -- --ignored --exact --nocapture --test-threads=1 > $O/a7merge_r2rung.log 2>&1; say "w16r2 rung golden rc=$?"
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 HL_M4_PHASES=1 HL_M4_WARM_PASSES=1 HL_M4_PROFILES=R13_SHIELD_T128_H24,R13_8B_T128_H24,W16_SHIELD_T128_H24,W16_8B_T128_H24,W16R2_SHIELD_T128_H24,W16R2_8B_T128_H24 $C $T::m4_trained_accuracy_block_cpu_and_metal_digests_and_times -- --ignored --exact --nocapture --test-threads=1 > $O/a7merge_trained.log 2>&1; say "trained digests rc=$?"
for d in 5a6193d3 f590b01f 79f987ef a8258241 0e88d84f 90003b76; do
  if grep -q "$d" $O/a7merge_trained.log; then say "digest $d present"; else say "DIGEST $d MISSING"; fi
done
env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=2 HL_D55_SEALED=1 HL_D55_PIPE=4 $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/a7merge_d55.log 2>&1; say "d55 default rc=$?"
grep -E "sealing pass|^D55-AB SUMMARY|^D55-AB PIPE" $O/a7merge_d55.log >> $P
say "all done"
