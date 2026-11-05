#!/bin/bash
# The F12 fix (D65(1)) merged onto the tree that already has D65(2), D66(3) and H124c. Acceptance on the MERGED tree:
# the new tests of both lines; the full lib suite with only the known three failures (one renamed by the F12 lane);
# the W16R2 rung golden at its new pin; the six trained digests at their NEW values (REPIN.md); the D55 harness's
# SEALED arm proving and verifying under the new strings. One guarded job, class gpu.
set -u
H=/Users/victorrielly/IntelligenceRegulation/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=/Users/victorrielly/IntelligenceRegulation/results/zk60_f12_fix_20261104
F=/Users/victorrielly/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
T=private_block::slot_ir::accuracy::tests
P=$O/merge.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$C --no-run > $O/merge_build.log 2>&1; say "build rc=$?"
for t in f12_ d65_the_external_refusal d66_the_dictionary_refusal l4_f3_ h124c_the_parallel_builder f1_every_slot; do
  $C $t > $O/merge_t_$t.log 2>&1; say "tests $t rc=$? $(grep -E '^test result' $O/merge_t_$t.log | head -1)"
done
env HL_R13_LOADER_FIXTURES=$F $C -- --test-threads=8 > $O/merge_full.log 2>&1; say "full lib suite rc=$? (expect failures: exactly the known three)"
grep -E "^test result|^    [a-z_:0-9]+$" $O/merge_full.log | tail -8 >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::w16r2_rung_cpu_and_metal_digests_equal_the_golden -- --ignored --exact --nocapture --test-threads=1 > $O/merge_r2rung.log 2>&1; say "w16r2 rung golden rc=$?"
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 HL_M4_PHASES=1 HL_M4_WARM_PASSES=1 HL_M4_PROFILES=R13_SHIELD_T128_H24,R13_8B_T128_H24,W16_SHIELD_T128_H24,W16_8B_T128_H24,W16R2_SHIELD_T128_H24,W16R2_8B_T128_H24 $C $T::m4_trained_accuracy_block_cpu_and_metal_digests_and_times -- --ignored --exact --nocapture --test-threads=1 > $O/merge_trained.log 2>&1; say "trained digests rc=$?"
for d in 5a6193d3 f590b01f 79f987ef a8258241 0e88d84f 90003b76; do
  if grep -q "$d" $O/merge_trained.log; then say "new digest $d present"; else say "NEW DIGEST $d MISSING"; fi
done
env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=1 HL_D55_SEALED=1 $C private_block::run::fork::tests::d55_ab_one_request_serial_against_forks -- --ignored --exact --nocapture --test-threads=1 > $O/merge_d55.log 2>&1; say "d55 A/B rc=$?"
grep -E "verified|^D55-AB SUMMARY" $O/merge_d55.log >> $P
say "all done"
