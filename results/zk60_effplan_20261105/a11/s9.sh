#!/bin/bash
# A11 stage 9, FINAL ACCEPTANCE on the final tree: build; a no-feature `cargo check --tests`; the full lib suite
# (expect only the known three failures); zkp-core's field tests (`from_u128`); the A11 byte tests (the seeded
# W16R2 rung inside per-fork pools, CPU and Metal); the A7 queue byte test; the W16R2 rung golden and the six
# post-F12 trained digests under HL_GPU_REQUIRED=1; the D55 harness on the final default, sealed one request
# and a 4-request stream, every receipt verified. One guarded job, class gpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-ae8b54c76e79d7cfe
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
Z=$W/ops/zkp-mvp/gpu-metal/zkp-core/Cargo.toml
O=$W/results/zk60_effplan_20261105/a11
F=/Users/victorrielly/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
T=private_block::slot_ir::accuracy::tests
D=private_block::run::fork::tests::d55_ab_one_request_serial_against_forks
P=$O/s9.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$C --no-run > $O/s9_build.log 2>&1; say "build rc=$?"
/opt/homebrew/bin/cargo check --tests --offline --locked --manifest-path $H > $O/s9_check_nometal.log 2>&1; say "no-feature cargo check --tests rc=$?"
env HL_R13_LOADER_FIXTURES=$F $C -- --test-threads=8 > $O/s9_full.log 2>&1; say "full lib suite rc=$? (expect failures: exactly the known three)"
grep -E "^test result|^    [a-z_:0-9]+$" $O/s9_full.log | tail -8 >> $P
/opt/homebrew/bin/cargo test --release --offline --locked --manifest-path $Z --lib field:: > $O/s9_zkpcore_field.log 2>&1; say "zkp-core field tests rc=$?"
grep -E "test result" $O/s9_zkpcore_field.log >> $P
$C private_block::w16r2_tests::a11_w16r2_rung_golden_inside_small_rayon_pools_and_in_every_host_matrix_mode -- --exact --nocapture --test-threads=1 > $O/s9_pools_cpu.log 2>&1; say "a11 CPU pool byte test rc=$?"
grep -E "A11-POOLS" $O/s9_pools_cpu.log | cut -c1-140 >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::a11_w16r2_rung_digests_in_per_fork_pools_on_the_device -- --ignored --exact --nocapture --test-threads=1 > $O/s9_pools_metal.log 2>&1; say "a11 Metal pool byte test rc=$?"
grep -E "A11-POOLS" $O/s9_pools_metal.log | cut -c1-160 >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::a7_w16r2_rung_digests_on_six_threads_at_one_and_at_six_queues -- --ignored --exact --nocapture --test-threads=1 > $O/s9_queues.log 2>&1; say "a7 queue byte test rc=$?"
grep -E "A7-QUEUES W16R2" $O/s9_queues.log | cut -c1-220 >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::w16r2_rung_cpu_and_metal_digests_equal_the_golden -- --ignored --exact --nocapture --test-threads=1 > $O/s9_r2rung.log 2>&1; say "w16r2 rung golden rc=$?"
grep -E "W16R2-RUNG-DIGEST" $O/s9_r2rung.log | cut -c1-220 >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 HL_M4_PHASES=1 HL_M4_WARM_PASSES=1 HL_M4_PROFILES=R13_SHIELD_T128_H24,R13_8B_T128_H24,W16_SHIELD_T128_H24,W16_8B_T128_H24,W16R2_SHIELD_T128_H24,W16R2_8B_T128_H24 $C $T::m4_trained_accuracy_block_cpu_and_metal_digests_and_times -- --ignored --exact --nocapture --test-threads=1 > $O/s9_trained.log 2>&1; say "trained digests rc=$?"
for d in 5a6193d3 f590b01f 79f987ef a8258241 0e88d84f 90003b76; do
  if grep -q "$d" $O/s9_trained.log; then say "digest $d present"; else say "DIGEST $d MISSING"; fi
done
env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=2 HL_D55_SEALED=1 HL_D55_PIPE=4 $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/s9_d55.log 2>&1; say "d55 final default rc=$?"
grep -E "sealing pass|verified|^D55-AB SUMMARY|^D55-AB PIPE|receipt [0-9]+ B" $O/s9_d55.log | cut -c1-260 >> $P
say "all done"
