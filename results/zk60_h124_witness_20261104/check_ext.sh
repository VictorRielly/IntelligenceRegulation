#!/bin/bash
# D63 L4 finding fix: the prover refuses an extension round that is not an identity (zk::extension).
# The full lib suite must show only the known three failures (898 / 3 / 92 on this tree), and the goldens
# and pinned digests must be unchanged. One guarded job, class gpu.
set -u
H=/Users/victorrielly/IntelligenceRegulation/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=/Users/victorrielly/IntelligenceRegulation/results/zk60_h124_witness_20261104
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
T=private_block::slot_ir::accuracy::tests
P=$O/ext.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$C --no-run > $O/ext_build.log 2>&1; say "build rc=$?"
$C > $O/ext_full.log 2>&1; say "full lib suite rc=$? (expect failures: exactly the known three)"
grep -E "^test result|^    private_block|^    [a-z_:]+$" $O/ext_full.log | tail -8 >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::w16r2_rung_cpu_and_metal_digests_equal_the_golden -- --ignored --exact --nocapture --test-threads=1 > $O/ext_r2rung.log 2>&1; say "w16r2 rung golden rc=$?"
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 HL_M4_PHASES=1 HL_M4_WARM_PASSES=1 HL_M4_PROFILES=R13_SHIELD_T128_H24,R13_8B_T128_H24,W16_SHIELD_T128_H24,W16_8B_T128_H24,W16R2_SHIELD_T128_H24,W16R2_8B_T128_H24 $C $T::m4_trained_accuracy_block_cpu_and_metal_digests_and_times -- --ignored --exact --nocapture --test-threads=1 > $O/ext_trained.log 2>&1; say "trained digests rc=$?"
for d in 2b0d04bb 678953f6 01a6d51d c5e0bdac 4e189ccc a9a19ee5; do
  if grep -q "$d" $O/ext_trained.log; then say "digest $d present"; else say "DIGEST $d MISSING"; fi
done
say "all done"
