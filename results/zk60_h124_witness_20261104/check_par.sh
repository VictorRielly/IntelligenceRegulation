#!/bin/bash
# H124c step 3: the builder's serial remainder parallelized (quantized, the score and softmax/PV loops, the weight
# scan, assign's supports). Acceptance: the parallel builder equals its sequential reference on every plane and
# refuses identically (six profiles); the full lib suite shows only the known three failures; the W16R2 rung golden
# and all six pinned trained digests are unchanged. Then the per-block time and the D55 A/B with the witness on
# the clock. One guarded job, class gpu.
set -u
H=/Users/victorrielly/IntelligenceRegulation/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=/Users/victorrielly/IntelligenceRegulation/results/zk60_h124_witness_20261104
F=/Users/victorrielly/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
T=private_block::slot_ir::accuracy::tests
P=$O/par.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$C --no-run > $O/par_build.log 2>&1; say "build rc=$?"
grep -E "^(warning|error)" $O/par_build.log | sort | uniq -c >> $P
$C h124c_the_parallel_builder_equals_the_sequential_one_on_every_plane -- --nocapture > $O/par_equality.log 2>&1; say "equality rc=$?"
grep -E "^H124c|^test |panicked" $O/par_equality.log >> $P
$C h124_witness_time_per_block_at_w16r2_8b_t128 -- --ignored --nocapture --test-threads=1 > $O/par_h124.log 2>&1; say "per-block timing rc=$?"
grep -E "^H124 " $O/par_h124.log >> $P
env HL_R13_LOADER_FIXTURES=$F $C -- --test-threads=8 > $O/par_full.log 2>&1; say "full lib suite rc=$? (expect failures: exactly the known three)"
grep -E "^test result|^    [a-z_:0-9]+$" $O/par_full.log | tail -8 >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::w16r2_rung_cpu_and_metal_digests_equal_the_golden -- --ignored --exact --nocapture --test-threads=1 > $O/par_r2rung.log 2>&1; say "w16r2 rung golden rc=$?"
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 HL_M4_PHASES=1 HL_M4_WARM_PASSES=1 HL_M4_PROFILES=R13_SHIELD_T128_H24,R13_8B_T128_H24,W16_SHIELD_T128_H24,W16_8B_T128_H24,W16R2_SHIELD_T128_H24,W16R2_8B_T128_H24 $C $T::m4_trained_accuracy_block_cpu_and_metal_digests_and_times -- --ignored --exact --nocapture --test-threads=1 > $O/par_trained.log 2>&1; say "trained digests rc=$?"
for d in 2b0d04bb 678953f6 01a6d51d c5e0bdac 4e189ccc a9a19ee5; do
  if grep -q "$d" $O/par_trained.log; then say "digest $d present"; else say "DIGEST $d MISSING"; fi
done
env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=2 HL_D55_JIT=2:4,4:6 $C private_block::run::fork::tests::d55_ab_one_request_serial_against_forks -- --ignored --exact --nocapture --test-threads=1 > $O/d55_ab_par.log 2>&1; say "d55 A/B rc=$?"
grep -E "sealing pass|^D55-AB SUMMARY" $O/d55_ab_par.log >> $P
say "all done"
