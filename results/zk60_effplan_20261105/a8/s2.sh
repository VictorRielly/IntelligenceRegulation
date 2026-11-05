#!/bin/bash
# A8 stage 2, THE A/B: build; then the in-process A/B at N = 6 of the tree before A8 (`m11+cols+vecfill`:
# the M11 store folds with the pads folded afterwards on one thread, the prover building every group's
# column weights, `A` and `H` written zero by `vec!`) against all of A8 (`small+nocols+calloc`), 6 passes,
# the arm order reversed in every odd pass; each arm and pass: a proof-only fork call, one request from its
# input (sealed) and a stream of 4 requests (every stream receipt verified after its clock; the first
# proof-only and sealed call of each arm verified). One guarded job, class gpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a6902a0faf57242d4
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$W/results/zk60_effplan_20261105/a8
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
D=private_block::run::fork::tests::d55_ab_one_request_serial_against_forks
BASE=m11+cols+vecfill
TEST=small+nocols+calloc
P=$O/s2.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$C --no-run > $O/s2_build.log 2>&1
rc=$?
say "build rc=$rc"
if [ $rc -ne 0 ]; then
  grep -E "^error" -A 12 $O/s2_build.log | head -80 >> $P
  say "all done (build failed)"
  exit 1
fi
T=private_block::w16r2_tests
$C $T::a8_store_fold_forms_equal_the_per_term_fold_word_for_word -- --exact --nocapture --test-threads=1 > $O/s2_equal.log 2>&1; say "word-for-word fold test rc=$?"
grep -E "A8-FOLD-EQUAL|test result|panicked" $O/s2_equal.log | cut -c1-300 >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C $T::a8_w16r2_rung_golden_under_every_store_fold_form -- --ignored --exact --nocapture --test-threads=1 > $O/s2_rung.log 2>&1; say "rung golden under every form rc=$?"
grep -E "A8-RUNG|test result|panicked" $O/s2_rung.log | cut -c1-200 >> $P
env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=1 HL_D55_AB_PASSES=6 HL_D55_AB_ALTERNATE=1 HL_D55_AB_SEALED=1 HL_D55_AB_PIPE=4 HL_D55_GPU_AB=$BASE,$TEST $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/s2_d55_ab.log 2>&1
say "d55 A/B rc=$?"
grep -E "^D55-AB SUMMARY" $O/s2_d55_ab.log | cut -c1-220 >> $P
python3 $W/results/zk60_effplan_20261105/a11/pairs.py $O/s2_d55_ab.log $BASE $TEST --alternate --n 6 > $O/s2_pairs.md 2>&1
cat $O/s2_pairs.md >> $P
say "all done"
