#!/bin/bash
# A12 stage 2, THE SECOND FORM: the device build encoded ahead of the slot's first round (no command buffer of
# its own) and A's and H's rows read from the commitments' resident device copies (no page views). Build; the
# no-feature `cargo check --tests`; the CPU formula test; the Metal census (now also the deferred form, flushed,
# word for word); the W16R2 rung golden with the tables on the host, on the device ahead of the first round,
# and on the device in their own command buffer (alone and three concurrent proofs); then the D55 map at N = 1
# and N = 6 of `hosttab`, `devtab` and `devtabsync`, 2 passes in alternating order, proof only, with the GPU
# timeline. One guarded job, class gpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a79e5d1184b3df41f
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$W/results/zk60_effplan_20261105/a12
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
D=private_block::run::fork::tests::d55_ab_one_request_serial_against_forks
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
/opt/homebrew/bin/cargo check --tests --offline --locked --manifest-path $H > $O/s2_check_nometal.log 2>&1; say "no-feature cargo check --tests rc=$?"
grep -E "^error" -A 8 $O/s2_check_nometal.log | head -40 >> $P
$C private_block::range16_tests::a12_the_device_table_formula_equals_the_host_builders_at_every_slot_of_the_w16r2_rung -- --exact --nocapture --test-threads=1 > $O/s2_formula.log 2>&1; say "a12 formula test (CPU) rc=$?"
grep -E "A12-FORMULA|test result|panicked" $O/s2_formula.log | cut -c1-240 >> $P
$C private_block::range16_tests::a12_census_and_the_device_tables_equal_the_host_tables_word_for_word -- --ignored --exact --nocapture --test-threads=1 > $O/s2_census.log 2>&1; say "a12 census + word-for-word (Metal) rc=$?"
grep -E "A12-CENSUS [^ ]+: |test result|panicked" $O/s2_census.log | cut -c1-360 >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::a12_w16r2_rung_golden_with_the_slot_tables_built_on_the_host_and_on_the_device -- --ignored --exact --nocapture --test-threads=1 > $O/s2_rung.log 2>&1; say "a12 rung golden, tables on host and device (both forms) rc=$?"
grep -E "A12-TABLES|test result|panicked" $O/s2_rung.log | cut -c1-300 >> $P
env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_TIMELINE=1 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=1,6 HL_D55_PASSES=1 HL_D55_AB_PASSES=2 HL_D55_AB_ALTERNATE=1 HL_D55_GPU_AB=hosttab,devtab,devtabsync $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/s2_d55_map.log 2>&1
say "d55 map rc=$?"
grep -E "^D55-AB GPU-AB|^D55-AB SUMMARY|panicked" $O/s2_d55_map.log | cut -c1-300 >> $P
python3 $O/summarize.py $O/s2_d55_map.log > $O/s2_summary.md 2>&1
cat $O/s2_summary.md >> $P
say "all done"
