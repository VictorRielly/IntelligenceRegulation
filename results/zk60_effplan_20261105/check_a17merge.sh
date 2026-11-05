#!/bin/bash
# Efficiency plan A17, merged into perf (its tree is perf 95d86252 + the agent's dd2644e7): acceptance on the MERGED
# tree in the main checkout, and an independent A/B. Build; a no-feature `cargo check --tests`; the full lib suite
# (expect only the known three failures; A17's suite tests are in it); zkp-core's whole lib suite; the A17 rung golden
# under every A17 setting (CPU and Metal) and the 8B block under every A17 setting; the A15 8B chain in every pool; the
# A14 8B private tables, the rung golden and the 8B block under every A14 setting; the A8 rung test; the A12 census and
# rung-mode tests; the A11 pool byte tests; the A7 queue byte test; the W16R2 rung golden and the six post-F12 digests
# under HL_GPU_REQUIRED=1; the D55 harness on the default; then an in-process A/B of `a17old` (the code before A17)
# against `a17new` (the A17 default), 4 passes, alternating arm order, independent of the agent's 6-pass run. One
# guarded job, class gpu.
set -u
R=/Users/victorrielly/IntelligenceRegulation
H=$R/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
Z=$R/ops/zkp-mvp/gpu-metal/zkp-core/Cargo.toml
O=$R/results/zk60_effplan_20261105
F=$R/results/zk60_1b_native_20261017/r13/loader-fixtures
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
T=private_block::slot_ir::accuracy::tests
D=private_block::run::fork::tests::d55_ab_one_request_serial_against_forks
P=$O/a17merge.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
# The timing steps wait for a quiet GPU: Victor's research agent (frugal-lm, Codex) runs GPU benchmarks outside the
# guard (2026-11-05, `ds4-bench*`). Byte tests run regardless; the clocks wait up to 4 h, and each clock records
# whether such a process was seen at its start or end.
EXT='ds4-bench'
quiet() {
  local n=0
  while pgrep -f "$EXT" > /dev/null; do
    if [ $n -eq 0 ]; then say "waiting for a quiet GPU ($EXT running): $1"; fi
    n=$((n + 1))
    if [ $n -ge 480 ]; then say "GPU still busy after 4 h; $1 runs anyway (TIMING POLLUTED)"; return; fi
    sleep 30
  done
  say "GPU quiet (no $EXT): $1"
}
seen() { if pgrep -f "$EXT" > /dev/null; then say "$EXT RUNNING at the end of $1 (TIMING POLLUTED)"; else say "no $EXT at the end of $1"; fi; }
say start
$C --no-run > $O/a17merge_build.log 2>&1
rc=$?
say "build rc=$rc"
if [ $rc -ne 0 ]; then
  grep -E "^error" -A 14 $O/a17merge_build.log | head -120 >> $P
  say "all done (build failed)"
  exit 1
fi
/opt/homebrew/bin/cargo check --tests --offline --locked --manifest-path $H > $O/a17merge_check_nometal.log 2>&1; say "no-feature cargo check --tests rc=$?"
env HL_R13_LOADER_FIXTURES=$F $C -- --test-threads=8 > $O/a17merge_full.log 2>&1; say "full lib suite rc=$? (expect failures: exactly the known three)"
grep -E "^test result|^    [a-z_:0-9]+$" $O/a17merge_full.log | tail -8 >> $P
grep -E "a17_|a15_the_seal_pool_rule|a14_the_lazy_sums|a12_the_device_table_formula|a8_store_fold_forms_equal" $O/a17merge_full.log | cut -c1-200 >> $P
/opt/homebrew/bin/cargo test --release --offline --locked --manifest-path $Z --lib > $O/a17merge_zkpcore.log 2>&1; say "zkp-core lib tests rc=$?"
grep -E "test result" $O/a17merge_zkpcore.log >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::a17_w16r2_rung_golden_under_every_a17_setting -- --ignored --exact --nocapture --test-threads=1 > $O/a17merge_a17rung.log 2>&1; say "a17 rung golden under every setting (CPU and Metal) rc=$?"
grep -E "A17-|test result|panicked" $O/a17merge_a17rung.log | cut -c1-240 >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 HL_PB_ORACLE=0 $C private_block::w16r2_tests::a17_the_8b_block_proves_the_same_under_every_a17_setting -- --ignored --exact --nocapture --test-threads=1 > $O/a17merge_a17_8b.log 2>&1; say "a17 8B block under every setting rc=$?"
grep -E "A17-|test result|panicked" $O/a17merge_a17_8b.log | cut -c1-240 >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::a15_the_8b_witness_planes_in_every_sealing_pool -- --ignored --exact --nocapture --test-threads=1 > $O/a17merge_a15_8b.log 2>&1; say "a15 8B chain in every pool (CPU and device products) rc=$?"
grep -E "test result|panicked" $O/a17merge_a15_8b.log | cut -c1-240 >> $P
$C private_block::range16_tests::a14_the_8b_private_slots_tables_equal_under_both_sums -- --ignored --exact --nocapture --test-threads=1 > $O/a17merge_lazy8b.log 2>&1; say "a14 8B private tables under both sums rc=$?"
grep -E "test result|panicked" $O/a17merge_lazy8b.log | cut -c1-200 >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::a14_w16r2_rung_golden_under_every_a14_setting -- --ignored --exact --nocapture --test-threads=1 > $O/a17merge_a14rung.log 2>&1; say "a14 rung golden under every setting rc=$?"
grep -E "test result|panicked" $O/a17merge_a14rung.log | cut -c1-200 >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 HL_PB_ORACLE=0 $C private_block::w16r2_tests::a14_the_8b_block_proves_the_same_under_every_a14_setting -- --ignored --exact --nocapture --test-threads=1 > $O/a17merge_a14_8b.log 2>&1; say "a14 8B block under every setting rc=$?"
grep -E "A14-8B|test result|panicked" $O/a17merge_a14_8b.log | cut -c1-200 >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::a8_w16r2_rung_golden_under_every_store_fold_form -- --ignored --exact --nocapture --test-threads=1 > $O/a17merge_a8rung.log 2>&1; say "a8 rung golden under every form rc=$?"
grep -E "test result|panicked" $O/a17merge_a8rung.log | cut -c1-200 >> $P
$C private_block::range16_tests::a12_census_and_the_device_tables_equal_the_host_tables_word_for_word -- --ignored --exact --nocapture --test-threads=1 > $O/a17merge_census.log 2>&1; say "a12 census + word-for-word (Metal) rc=$?"
grep -E "test result|panicked" $O/a17merge_census.log | cut -c1-360 >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::a12_w16r2_rung_golden_with_the_slot_tables_built_on_the_host_and_on_the_device -- --ignored --exact --nocapture --test-threads=1 > $O/a17merge_rung_modes.log 2>&1; say "a12 rung golden in every table mode rc=$?"
grep -E "test result|panicked" $O/a17merge_rung_modes.log | cut -c1-300 >> $P
$C private_block::w16r2_tests::a11_w16r2_rung_golden_inside_small_rayon_pools -- --exact --nocapture --test-threads=1 > $O/a17merge_pools_cpu.log 2>&1; say "a11 CPU pool byte test rc=$?"
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::a11_w16r2_rung_digests_in_per_fork_pools_on_the_device -- --ignored --exact --nocapture --test-threads=1 > $O/a17merge_pools_metal.log 2>&1; say "a11 Metal pool byte test rc=$?"
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::a7_w16r2_rung_digests_on_six_threads_at_one_and_at_six_queues -- --ignored --exact --nocapture --test-threads=1 > $O/a17merge_queues.log 2>&1; say "a7 queue byte test rc=$?"
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::w16r2_rung_cpu_and_metal_digests_equal_the_golden -- --ignored --exact --nocapture --test-threads=1 > $O/a17merge_r2rung.log 2>&1; say "w16r2 rung golden rc=$?"
grep -E "W16R2-RUNG-DIGEST" $O/a17merge_r2rung.log | cut -c1-220 >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 HL_M4_PHASES=1 HL_M4_WARM_PASSES=1 HL_M4_PROFILES=R13_SHIELD_T128_H24,R13_8B_T128_H24,W16_SHIELD_T128_H24,W16_8B_T128_H24,W16R2_SHIELD_T128_H24,W16R2_8B_T128_H24 $C $T::m4_trained_accuracy_block_cpu_and_metal_digests_and_times -- --ignored --exact --nocapture --test-threads=1 > $O/a17merge_trained.log 2>&1; say "trained digests rc=$?"
for d in 5a6193d3 f590b01f 79f987ef a8258241 0e88d84f 90003b76; do
  if grep -q "$d" $O/a17merge_trained.log; then say "digest $d present"; else say "DIGEST $d MISSING"; fi
done
quiet "d55 default"
env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=2 HL_D55_SEALED=1 HL_D55_PIPE=4 $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/a17merge_d55.log 2>&1; say "d55 default rc=$?"
seen "d55 default"
grep -E "sealing pass|verified|receipt [0-9]+ B|^D55-AB SUMMARY|^D55-AB PIPE|A15 SEALED|A15 PIPE-SEAL" $O/a17merge_d55.log | cut -c1-260 >> $P
quiet "d55 A/B"
env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=1 HL_D55_AB_PASSES=4 HL_D55_AB_ALTERNATE=1 HL_D55_AB_SEALED=1 HL_D55_AB_PIPE=4 HL_D55_GPU_AB=a17old,a17new $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/a17merge_d55_ab.log 2>&1; say "d55 A/B a17old against a17new rc=$?"
seen "d55 A/B"
python3 $O/a11/pairs.py $O/a17merge_d55_ab.log a17old a17new --alternate --n 6 > $O/a17merge_pairs.md 2>&1
python3 $O/a15/seal_pairs.py $O/a17merge_d55_ab.log a17old a17new --n 6 > $O/a17merge_seal_pairs.md 2>&1
cat $O/a17merge_pairs.md $O/a17merge_seal_pairs.md >> $P
say "all done"
