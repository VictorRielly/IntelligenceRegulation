#!/bin/bash
# (1) The finding-3 audit fix with the review fixture corrected: the full lib suite must show only the known three
#     failures. (2) D64 / H124c: the D55 A/B with extra fork arms that build every witness ON the clock (HL_D55_JIT
#     builders:ahead pairs) and the sealing pass timed. One guarded job, class gpu.
set -u
H=/Users/victorrielly/IntelligenceRegulation/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=/Users/victorrielly/IntelligenceRegulation/results/zk60_h124_witness_20261104
F=/Users/victorrielly/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
P=$O/jit.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$C --no-run > $O/jit_build.log 2>&1; say "build rc=$?"
env HL_R13_LOADER_FIXTURES=$F $C -- --test-threads=8 > $O/f3_full2.log 2>&1; say "full lib suite rc=$? (expect failures: exactly the known three)"
grep -E "^test result|^    [a-z_:0-9]+$" $O/f3_full2.log | tail -8 >> $P
$C private_block::review_tests::the_mask_schedule_audit_still_refuses_every_case_at_the_rungs_row_width -- --exact --nocapture > $O/f3_review.log 2>&1; say "review fixture test rc=$?"
env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=2 HL_D55_JIT=2:4,4:6,8:8 $C private_block::run::fork::tests::d55_ab_one_request_serial_against_forks -- --ignored --exact --nocapture --test-threads=1 > $O/d55_ab_jit.log 2>&1; say "d55 A/B with JIT arms rc=$?"
grep -E "sealing pass|^D55-AB SUMMARY|JIT .* pass|verified" $O/d55_ab_jit.log >> $P
say "all done"
