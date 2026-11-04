#!/bin/bash
# H124 step 2 (the i16 products tiled by output columns): exactness and byte identity, then the time again.
# Run inside ONE guarded job (class gpu: the digest tests prove on Metal too). Each step's exit goes to tiled.progress.
set -u
H=/Users/victorrielly/IntelligenceRegulation/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=/Users/victorrielly/IntelligenceRegulation/results/zk60_h124_witness_20261104
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
T=private_block::slot_ir::accuracy::tests
P=$O/tiled.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$C --no-run > $O/tiled_build.log 2>&1; say "build rc=$?"
$C witness_speed_tests -- --include-ignored --nocapture --test-threads=1 > $O/tiled_equality.log 2>&1; say "equality (incl. TinyLlama dims, extremes, timing) rc=$?"
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::w16r2_rung_cpu_and_metal_digests_equal_the_golden -- --ignored --exact --nocapture --test-threads=1 > $O/tiled_r2rung.log 2>&1; say "w16r2 rung golden rc=$?"
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 HL_M4_PHASES=1 HL_M4_WARM_PASSES=1 HL_M4_PROFILES=R13_SHIELD_T128_H24,R13_8B_T128_H24,W16_SHIELD_T128_H24,W16_8B_T128_H24,W16R2_SHIELD_T128_H24,W16R2_8B_T128_H24 $C $T::m4_trained_accuracy_block_cpu_and_metal_digests_and_times -- --ignored --exact --nocapture --test-threads=1 > $O/tiled_trained.log 2>&1; say "trained digests rc=$?"
# the pinned trained digests (D60 gate chain and the Q = 280 recount): each must appear
for d in 2b0d04bb 678953f6 01a6d51d c5e0bdac 4e189ccc a9a19ee5; do
  if grep -q "$d" $O/tiled_trained.log; then say "digest $d present"; else say "DIGEST $d MISSING"; fi
done
say "all done"
