#!/bin/bash
# D65(2): the prove commands print one constant external refusal, with the detail in the owner's private log.
# D66(3): the DD dictionary's LogUp refusal is challenge-only (dd_challenge_refusal). Neither may move a receipt byte in
# an honest flow. Acceptance: the two new tests pass; the full lib suite shows only the known three failures; the
# W16R2 rung golden and the six pinned trained digests are unchanged. One guarded job, class gpu.
set -u
H=/Users/victorrielly/IntelligenceRegulation/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=/Users/victorrielly/IntelligenceRegulation/results/zk60_h124_witness_20261104
F=/Users/victorrielly/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
T=private_block::slot_ir::accuracy::tests
P=$O/d65d66.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$C --no-run > $O/d65d66_build.log 2>&1; say "build rc=$?"
$C d65_the_external_refusal_is_constant_and_the_detail_stays_private > $O/d65_test.log 2>&1; say "d65 test rc=$?"
$C d66_the_dictionary_refusal_is_challenge_only_and_covers_every_admissible_tuple > $O/d66_test.log 2>&1; say "d66 test rc=$?"
env HL_R13_LOADER_FIXTURES=$F $C -- --test-threads=8 > $O/d65d66_full.log 2>&1; say "full lib suite rc=$? (expect failures: exactly the known three)"
grep -E "^test result|^    [a-z_:0-9]+$" $O/d65d66_full.log | tail -8 >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::w16r2_rung_cpu_and_metal_digests_equal_the_golden -- --ignored --exact --nocapture --test-threads=1 > $O/d65d66_r2rung.log 2>&1; say "w16r2 rung golden rc=$?"
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 HL_M4_PHASES=1 HL_M4_WARM_PASSES=1 HL_M4_PROFILES=R13_SHIELD_T128_H24,R13_8B_T128_H24,W16_SHIELD_T128_H24,W16_8B_T128_H24,W16R2_SHIELD_T128_H24,W16R2_8B_T128_H24 $C $T::m4_trained_accuracy_block_cpu_and_metal_digests_and_times -- --ignored --exact --nocapture --test-threads=1 > $O/d65d66_trained.log 2>&1; say "trained digests rc=$?"
for d in 2b0d04bb 678953f6 01a6d51d c5e0bdac 4e189ccc a9a19ee5; do
  if grep -q "$d" $O/d65d66_trained.log; then say "digest $d present"; else say "DIGEST $d MISSING"; fi
done
say "all done"
