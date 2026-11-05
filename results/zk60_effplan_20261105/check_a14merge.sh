#!/bin/bash
# Efficiency plan A14, merged into perf (with A13's results-only commit), and the coordinator's change of the default
# XOF form to blake3 (HL_RNG_XOF=lanes8 opts in): acceptance on the MERGED tree, and an independent repeat of the A/B.
# Build; a no-feature `cargo check --tests`; the full lib suite (expect only the known three failures; A14's lazy-sum
# test is in it); zkp-core's whole lib suite (rng.rs and transcript.rs changed, with their XOF and absorb byte tests);
# the A14 8B private tables, the rung golden and the 8B block under every A14 setting; the A8 rung test; the A12 census
# and rung-mode tests; the A11 pool byte tests; the A7 queue byte test; the W16R2 rung golden and the six post-F12
# digests under HL_GPU_REQUIRED=1; the D55 harness on the default; then an in-process A/B of `lazy0` (the per-term sums,
# pre-A14) against `lazy1` (the new default), 4 passes, alternating arm order. One guarded job, class gpu.
set -u
R=/Users/victorrielly/IntelligenceRegulation
H=$R/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
Z=$R/ops/zkp-mvp/gpu-metal/zkp-core/Cargo.toml
O=$R/results/zk60_effplan_20261105
F=$R/results/zk60_1b_native_20261017/r13/loader-fixtures
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
T=private_block::slot_ir::accuracy::tests
D=private_block::run::fork::tests::d55_ab_one_request_serial_against_forks
P=$O/a14merge.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$C --no-run > $O/a14merge_build.log 2>&1; say "build rc=$?"
/opt/homebrew/bin/cargo check --tests --offline --locked --manifest-path $H > $O/a14merge_check_nometal.log 2>&1; say "no-feature cargo check --tests rc=$?"
env HL_R13_LOADER_FIXTURES=$F $C -- --test-threads=8 > $O/a14merge_full.log 2>&1; say "full lib suite rc=$? (expect failures: exactly the known three)"
grep -E "^test result|^    [a-z_:0-9]+$" $O/a14merge_full.log | tail -8 >> $P
grep -E "a14_the_lazy_sums|a12_the_device_table_formula|a8_store_fold_forms_equal" $O/a14merge_full.log | cut -c1-200 >> $P
/opt/homebrew/bin/cargo test --release --offline --locked --manifest-path $Z --lib > $O/a14merge_zkpcore.log 2>&1; say "zkp-core lib tests rc=$?"
grep -E "test result" $O/a14merge_zkpcore.log >> $P
$C private_block::range16_tests::a14_the_8b_private_slots_tables_equal_under_both_sums -- --ignored --exact --nocapture --test-threads=1 > $O/a14merge_lazy8b.log 2>&1; say "a14 8B private tables under both sums rc=$?"
grep -E "A14-|test result|panicked" $O/a14merge_lazy8b.log | cut -c1-200 >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::a14_w16r2_rung_golden_under_every_a14_setting -- --ignored --exact --nocapture --test-threads=1 > $O/a14merge_a14rung.log 2>&1; say "a14 rung golden under every setting rc=$?"
grep -E "A14-|test result|panicked" $O/a14merge_a14rung.log | cut -c1-200 >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 HL_PB_ORACLE=0 $C private_block::w16r2_tests::a14_the_8b_block_proves_the_same_under_every_a14_setting -- --ignored --exact --nocapture --test-threads=1 > $O/a14merge_a14_8b.log 2>&1; say "a14 8B block under every setting rc=$?"
grep -E "A14-|test result|panicked" $O/a14merge_a14_8b.log | cut -c1-200 >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::a8_w16r2_rung_golden_under_every_store_fold_form -- --ignored --exact --nocapture --test-threads=1 > $O/a14merge_a8rung.log 2>&1; say "a8 rung golden under every form rc=$?"
grep -E "A8-RUNG|test result|panicked" $O/a14merge_a8rung.log | cut -c1-200 >> $P
$C private_block::range16_tests::a12_census_and_the_device_tables_equal_the_host_tables_word_for_word -- --ignored --exact --nocapture --test-threads=1 > $O/a14merge_census.log 2>&1; say "a12 census + word-for-word (Metal) rc=$?"
grep -E "A12-CENSUS [^ ]+: |test result|panicked" $O/a14merge_census.log | cut -c1-360 >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::a12_w16r2_rung_golden_with_the_slot_tables_built_on_the_host_and_on_the_device -- --ignored --exact --nocapture --test-threads=1 > $O/a14merge_rung_modes.log 2>&1; say "a12 rung golden in every table mode rc=$?"
grep -E "A12-TABLES|test result|panicked" $O/a14merge_rung_modes.log | cut -c1-300 >> $P
$C private_block::w16r2_tests::a11_w16r2_rung_golden_inside_small_rayon_pools -- --exact --nocapture --test-threads=1 > $O/a14merge_pools_cpu.log 2>&1; say "a11 CPU pool byte test rc=$?"
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::a11_w16r2_rung_digests_in_per_fork_pools_on_the_device -- --ignored --exact --nocapture --test-threads=1 > $O/a14merge_pools_metal.log 2>&1; say "a11 Metal pool byte test rc=$?"
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::a7_w16r2_rung_digests_on_six_threads_at_one_and_at_six_queues -- --ignored --exact --nocapture --test-threads=1 > $O/a14merge_queues.log 2>&1; say "a7 queue byte test rc=$?"
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::w16r2_rung_cpu_and_metal_digests_equal_the_golden -- --ignored --exact --nocapture --test-threads=1 > $O/a14merge_r2rung.log 2>&1; say "w16r2 rung golden rc=$?"
grep -E "W16R2-RUNG-DIGEST" $O/a14merge_r2rung.log | cut -c1-220 >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 HL_M4_PHASES=1 HL_M4_WARM_PASSES=1 HL_M4_PROFILES=R13_SHIELD_T128_H24,R13_8B_T128_H24,W16_SHIELD_T128_H24,W16_8B_T128_H24,W16R2_SHIELD_T128_H24,W16R2_8B_T128_H24 $C $T::m4_trained_accuracy_block_cpu_and_metal_digests_and_times -- --ignored --exact --nocapture --test-threads=1 > $O/a14merge_trained.log 2>&1; say "trained digests rc=$?"
for d in 5a6193d3 f590b01f 79f987ef a8258241 0e88d84f 90003b76; do
  if grep -q "$d" $O/a14merge_trained.log; then say "digest $d present"; else say "DIGEST $d MISSING"; fi
done
env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=2 HL_D55_SEALED=1 HL_D55_PIPE=4 $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/a14merge_d55.log 2>&1; say "d55 default rc=$?"
grep -E "sealing pass|verified|^D55-AB SUMMARY|^D55-AB PIPE" $O/a14merge_d55.log | cut -c1-260 >> $P
env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=1 HL_D55_AB_PASSES=4 HL_D55_AB_ALTERNATE=1 HL_D55_AB_SEALED=1 HL_D55_AB_PIPE=4 HL_D55_GPU_AB=lazy0,lazy1 $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/a14merge_d55_ab.log 2>&1; say "d55 A/B lazy0 against lazy1 rc=$?"
python3 $O/a11/pairs.py $O/a14merge_d55_ab.log lazy0 lazy1 --alternate --n 6 > $O/a14merge_pairs.md 2>&1
cat $O/a14merge_pairs.md >> $P
say "all done"
