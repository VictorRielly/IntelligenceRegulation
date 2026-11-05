#!/bin/bash
# A8 stage 4, THE CONFIRMATORY A/B (after stage 3 dropped the zeroed allocation): build; the word-for-word
# fold test and the rung golden under every form; then in-process at N = 6, 6 passes, the whole arm order
# reversed in every odd pass, three arms: the tree before A8 (`m11+cols`), the small-word store fold
# (`small+cols`), and the small-word store fold with the prover's column weights skipped (`small+nocols`);
# each arm and pass: a proof-only fork call, one request from its input (sealed) and a stream of 4 requests
# (every stream receipt verified after its clock; the first proof-only and sealed call of each arm
# verified). One guarded job, class gpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a6902a0faf57242d4
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$W/results/zk60_effplan_20261105/a8
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
T=private_block::w16r2_tests
D=private_block::run::fork::tests::d55_ab_one_request_serial_against_forks
P=$O/s4.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$C --no-run > $O/s4_build.log 2>&1
rc=$?
say "build rc=$rc"
if [ $rc -ne 0 ]; then
  grep -E "^error" -A 12 $O/s4_build.log | head -80 >> $P
  say "all done (build failed)"
  exit 1
fi
$C $T::a8_store_fold_forms_equal_the_per_term_fold_word_for_word -- --exact --nocapture --test-threads=1 > $O/s4_equal.log 2>&1; say "word-for-word fold test rc=$?"
grep -E "A8-FOLD-EQUAL|test result|panicked" $O/s4_equal.log | cut -c1-300 >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C $T::a8_w16r2_rung_golden_under_every_store_fold_form -- --ignored --exact --nocapture --test-threads=1 > $O/s4_rung.log 2>&1; say "rung golden under every form rc=$?"
grep -E "A8-RUNG|test result|panicked" $O/s4_rung.log | cut -c1-200 >> $P
env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=1 HL_D55_AB_PASSES=6 HL_D55_AB_ALTERNATE=1 HL_D55_AB_SEALED=1 HL_D55_AB_PIPE=4 HL_D55_GPU_AB=m11+cols,small+cols,small+nocols $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/s4_d55_ab.log 2>&1
say "d55 A/B rc=$?"
grep -E "^D55-AB SUMMARY" $O/s4_d55_ab.log | cut -c1-220 >> $P
A11=$W/results/zk60_effplan_20261105/a11/pairs.py
python3 $A11 $O/s4_d55_ab.log m11+cols small+cols --alternate --n 6 > $O/s4_pairs_small.md 2>&1
python3 $A11 $O/s4_d55_ab.log m11+cols small+nocols --alternate --n 6 > $O/s4_pairs_small+nocols.md 2>&1
python3 $A11 $O/s4_d55_ab.log small+cols small+nocols --alternate --n 6 > $O/s4_pairs_nocols_given_small.md 2>&1
cat $O/s4_pairs_small.md $O/s4_pairs_small+nocols.md $O/s4_pairs_nocols_given_small.md >> $P
say "all done"
