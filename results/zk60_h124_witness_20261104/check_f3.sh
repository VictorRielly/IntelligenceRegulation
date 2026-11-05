#!/bin/bash
# D63 L4 finding 3 fix: audit_claims (block and attention) refuses a reserved pair, or the zero-sum pair, whose
# INDUCED row weights are dependent over the base field. Honest claims weight a pair (c, c u), so nothing may change:
# the full lib suite must show only the known three failures, the new negative tests must pass, and the W16R2 rung
# golden must still match. One guarded job, class gpu.
set -u
H=/Users/victorrielly/IntelligenceRegulation/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=/Users/victorrielly/IntelligenceRegulation/results/zk60_h124_witness_20261104
F=/Users/victorrielly/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
P=$O/f3.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$C --no-run > $O/f3_build.log 2>&1; say "build rc=$?"
env HL_R13_LOADER_FIXTURES=$F $C -- --test-threads=8 > $O/f3_full.log 2>&1; say "full lib suite rc=$? (expect failures: exactly the known three)"
grep -E "^test result|^    [a-z_:0-9]+$" $O/f3_full.log | tail -8 >> $P
$C l4_f3_the_schedule_audit_refuses_a_pair_with_dependent_induced_weights -- --nocapture > $O/f3_test.log 2>&1; say "l4_f3 tests rc=$?"
grep -E "^test |^test result" $O/f3_test.log >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::w16r2_rung_cpu_and_metal_digests_equal_the_golden -- --ignored --exact --nocapture --test-threads=1 > $O/f3_r2rung.log 2>&1; say "w16r2 rung golden rc=$?"
say "all done"
