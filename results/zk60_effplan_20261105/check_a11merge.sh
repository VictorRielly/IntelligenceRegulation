#!/bin/bash
# Efficiency plan A11, merged into perf: acceptance on the MERGED tree, and an independent repeat of the A/B. Build;
# a no-feature `cargo check --tests`; the full lib suite (expect only the known three failures); zkp-core's field
# tests; the A11 pool byte tests (CPU and Metal); the A7 queue byte test; the W16R2 rung golden and the six post-F12
# digests under HL_GPU_REQUIRED=1; the D55 harness on the default (sealed one request and a 4-request stream); then an
# in-process A/B of `global` (pre-A11) against `fpauto` (the new default), 4 passes, alternating arm order. One
# guarded job, class gpu.
set -u
R=/Users/victorrielly/IntelligenceRegulation
H=$R/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
Z=$R/ops/zkp-mvp/gpu-metal/zkp-core/Cargo.toml
O=$R/results/zk60_effplan_20261105
F=$R/results/zk60_1b_native_20261017/r13/loader-fixtures
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
T=private_block::slot_ir::accuracy::tests
D=private_block::run::fork::tests::d55_ab_one_request_serial_against_forks
P=$O/a11merge.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$C --no-run > $O/a11merge_build.log 2>&1; say "build rc=$?"
/opt/homebrew/bin/cargo check --tests --offline --locked --manifest-path $H > $O/a11merge_check_nometal.log 2>&1; say "no-feature cargo check --tests rc=$?"
env HL_R13_LOADER_FIXTURES=$F $C -- --test-threads=8 > $O/a11merge_full.log 2>&1; say "full lib suite rc=$? (expect failures: exactly the known three)"
grep -E "^test result|^    [a-z_:0-9]+$" $O/a11merge_full.log | tail -8 >> $P
/opt/homebrew/bin/cargo test --release --offline --locked --manifest-path $Z --lib field:: > $O/a11merge_zkpcore_field.log 2>&1; say "zkp-core field tests rc=$?"
grep -E "test result" $O/a11merge_zkpcore_field.log >> $P
$C private_block::w16r2_tests::a11_w16r2_rung_golden_inside_small_rayon_pools -- --exact --nocapture --test-threads=1 > $O/a11merge_pools_cpu.log 2>&1; say "a11 CPU pool byte test rc=$?"
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::a11_w16r2_rung_digests_in_per_fork_pools_on_the_device -- --ignored --exact --nocapture --test-threads=1 > $O/a11merge_pools_metal.log 2>&1; say "a11 Metal pool byte test rc=$?"
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::a7_w16r2_rung_digests_on_six_threads_at_one_and_at_six_queues -- --ignored --exact --nocapture --test-threads=1 > $O/a11merge_queues.log 2>&1; say "a7 queue byte test rc=$?"
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::w16r2_rung_cpu_and_metal_digests_equal_the_golden -- --ignored --exact --nocapture --test-threads=1 > $O/a11merge_r2rung.log 2>&1; say "w16r2 rung golden rc=$?"
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 HL_M4_PHASES=1 HL_M4_WARM_PASSES=1 HL_M4_PROFILES=R13_SHIELD_T128_H24,R13_8B_T128_H24,W16_SHIELD_T128_H24,W16_8B_T128_H24,W16R2_SHIELD_T128_H24,W16R2_8B_T128_H24 $C $T::m4_trained_accuracy_block_cpu_and_metal_digests_and_times -- --ignored --exact --nocapture --test-threads=1 > $O/a11merge_trained.log 2>&1; say "trained digests rc=$?"
for d in 5a6193d3 f590b01f 79f987ef a8258241 0e88d84f 90003b76; do
  if grep -q "$d" $O/a11merge_trained.log; then say "digest $d present"; else say "DIGEST $d MISSING"; fi
done
env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=2 HL_D55_SEALED=1 HL_D55_PIPE=4 $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/a11merge_d55.log 2>&1; say "d55 default rc=$?"
grep -E "sealing pass|verified|^D55-AB SUMMARY|^D55-AB PIPE" $O/a11merge_d55.log | cut -c1-260 >> $P
env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=1 HL_D55_AB_PASSES=4 HL_D55_AB_ALTERNATE=1 HL_D55_AB_SEALED=1 HL_D55_AB_PIPE=4 HL_D55_GPU_AB=global,fpauto $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/a11merge_d55_ab.log 2>&1; say "d55 A/B global against fpauto rc=$?"
python3 $O/a11/pairs.py $O/a11merge_d55_ab.log global fpauto --alternate --n 4 > $O/a11merge_pairs.md 2>&1
cat $O/a11merge_pairs.md >> $P
say "all done"
