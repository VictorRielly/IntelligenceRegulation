#!/bin/bash
# Efficiency plan A2 (H122): the D55 preflight checks every block in parallel, and the int8 symmetry scan runs in
# parallel chunks (byte-preserving). A1: the uncontended phase breakdown of one 8B block (HL_PB_TIMING=1, one fork
# worker). Acceptance: full lib suite with only the known three failures; W16R2 rung golden; the six post-F12 trained
# digests; the D55 A/B (sealed one-request arm and a 4-request stream) to measure the preflight. One guarded job,
# class gpu.
set -u
H=/Users/victorrielly/IntelligenceRegulation/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=/Users/victorrielly/IntelligenceRegulation/results/zk60_h124_witness_20261104
F=/Users/victorrielly/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
T=private_block::slot_ir::accuracy::tests
D=private_block::run::fork::tests::d55_ab_one_request_serial_against_forks
P=$O/a1a2.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$C --no-run > $O/a1a2_build.log 2>&1; say "build rc=$?"
env HL_R13_LOADER_FIXTURES=$F $C -- --test-threads=8 > $O/a1a2_full.log 2>&1; say "full lib suite rc=$? (expect failures: exactly the known three)"
grep -E "^test result|^    [a-z_:0-9]+$" $O/a1a2_full.log | tail -8 >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::w16r2_rung_cpu_and_metal_digests_equal_the_golden -- --ignored --exact --nocapture --test-threads=1 > $O/a1a2_r2rung.log 2>&1; say "w16r2 rung golden rc=$?"
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 HL_M4_PHASES=1 HL_M4_WARM_PASSES=1 HL_M4_PROFILES=R13_SHIELD_T128_H24,R13_8B_T128_H24,W16_SHIELD_T128_H24,W16_8B_T128_H24,W16R2_SHIELD_T128_H24,W16R2_8B_T128_H24 $C $T::m4_trained_accuracy_block_cpu_and_metal_digests_and_times -- --ignored --exact --nocapture --test-threads=1 > $O/a1a2_trained.log 2>&1; say "trained digests rc=$?"
for d in 5a6193d3 f590b01f 79f987ef a8258241 0e88d84f 90003b76; do
  if grep -q "$d" $O/a1a2_trained.log; then say "digest $d present"; else say "DIGEST $d MISSING"; fi
done
env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=2 HL_D55_SEALED=1 HL_D55_PIPE=4 $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/d55_ab_a2.log 2>&1; say "d55 A/B rc=$?"
grep -E "sealing pass|forks N6 pass|SEALED pass|^D55-AB SUMMARY|^D55-AB PIPE" $O/d55_ab_a2.log >> $P
env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_PB_TIMING=1 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=4 HL_D55_WORKERS=1 HL_D55_PASSES=1 $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/a1_phases.log 2>&1; say "A1 phase breakdown rc=$?"
say "all done"
