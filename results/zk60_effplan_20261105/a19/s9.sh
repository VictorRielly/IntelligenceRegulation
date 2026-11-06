#!/bin/bash
# A19 acceptance on the final tree: `check_a18merge.sh`'s whole list pointed at this worktree, plus A19's tests. Build;
# a no-feature `cargo check --tests`; the full lib suite (expect only the known three failures; A19's two suite tests
# are in it); zkp-core's whole lib suite; A19's device tests (the planned path and its controls; production's D55 path,
# the window off and on, the blocks shared and reloaded, a refused chain); the A18 rung golden under every A18 setting
# (CPU and Metal), the A18 8B block, A13's parked forks on the device; the A16 8B witness planes in every form; the A17
# rung golden and 8B block; the A15 8B chain in every pool; the A14 8B private tables, rung golden and 8B block; the A8
# rung test; the A12 census and rung-mode tests; the A11 pool byte tests; the A7 queue byte test; the W16R2 rung golden
# and the six post-F12 digests under HL_GPU_REQUIRED=1; the D55 harness on the default; production's D55 path on the
# default (2 passes). Timing stages wait for a quiet GPU (no `ds4-bench`). One guarded job, class gpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a1f45d632690f8326
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
Z=$W/ops/zkp-mvp/gpu-metal/zkp-core/Cargo.toml
O=$W/results/zk60_effplan_20261105/a19
F=/Users/victorrielly/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
T=private_block::slot_ir::accuracy::tests
D=private_block::run::fork::tests::d55_ab_one_request_serial_against_forks
K=private_block::run::fork::tests
P=$O/s9.progress
R=$O/raw
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
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
$C --no-run > $R/s9_build.log 2>&1
rc=$?
say "build rc=$rc"
if [ $rc -ne 0 ]; then
  grep -E "^error" -A 14 $R/s9_build.log | head -120 >> $P
  say "all done (build failed)"
  exit 1
fi
grep -E "^warning" -A 6 $R/s9_build.log | head -40 >> $P
/opt/homebrew/bin/cargo check --tests --offline --locked --manifest-path $H > $R/s9_check_nometal.log 2>&1; say "no-feature cargo check --tests rc=$?"
# A19: the production (non-test) library too, its warnings in this lane's files listed
/opt/homebrew/bin/cargo build --release --offline --locked --features gpu-metal --manifest-path $H --lib > $R/s9_build_prod.log 2>&1; say "production library build (non-test, gpu-metal) rc=$?"
grep -E "^warning" -A 3 $R/s9_build_prod.log | grep -E "run_fork.rs|trained_block.rs" -B 3 | head -20 >> $P
env HL_R13_LOADER_FIXTURES=$F $C -- --test-threads=8 > $R/s9_full.log 2>&1; say "full lib suite rc=$? (expect failures: exactly the known three)"
grep -E "^test result|^    [a-z_:0-9]+$" $R/s9_full.log | tail -8 >> $P
grep -E "a19_|a18_|a16_|a17_|h124c_the_parallel|a4_the_device_builder|a15_the_seal_pool_rule|a14_the_lazy_sums|a12_the_device_table_formula|a8_store_fold_forms_equal|d60_f3|d60_f8" $R/s9_full.log | cut -c1-200 >> $P
/opt/homebrew/bin/cargo test --release --offline --locked --manifest-path $Z --lib > $R/s9_zkpcore.log 2>&1; say "zkp-core lib tests rc=$?"
grep -E "test result" $R/s9_zkpcore.log >> $P
env HL_R13_LOADER_FIXTURES=$F HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C $K::a19_planned_parts_equal_whole_forks_and_every_control_refuses_at_the_w16r2_rung_on_the_device -- --ignored --exact --nocapture --test-threads=1 > $R/s9_a19_planned_metal.log 2>&1; say "a19 planned path + controls on the device rc=$?"
grep -E "A19-|test result|panicked" $R/s9_a19_planned_metal.log | cut -c1-300 >> $P
env HL_R13_LOADER_FIXTURES=$F HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C $K::a19_production_d55_path_window_on_and_off_and_a_refused_chain_at_the_r13_rung_on_the_device -- --ignored --exact --nocapture --test-threads=1 > $R/s9_a19_prod_metal.log 2>&1; say "a19 production path on the device rc=$?"
grep -E "A19-|test result|panicked" $R/s9_a19_prod_metal.log | cut -c1-300 >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::a18_w16r2_rung_golden_under_every_a18_setting -- --ignored --exact --nocapture --test-threads=1 > $R/s9_a18rung.log 2>&1; say "a18 rung golden under every setting (CPU and Metal, three entries) rc=$?"
grep -E "test result|panicked" $R/s9_a18rung.log | cut -c1-240 >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 HL_PB_ORACLE=0 $C private_block::w16r2_tests::a18_the_8b_block_proves_the_same_under_every_a18_setting -- --ignored --exact --nocapture --test-threads=1 > $R/s9_a18_8b.log 2>&1; say "a18 8B block under every setting rc=$?"
grep -E "A18-|test result|panicked" $R/s9_a18_8b.log | cut -c1-240 >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C $K::a18_parked_forks_equal_whole_forks_byte_for_byte_at_the_w16r2_rung_on_the_device -- --ignored --exact --nocapture --test-threads=1 > $R/s9_a18_parked_metal.log 2>&1; say "a18 parked forks = whole forks on the device rc=$?"
grep -E "test result|panicked" $R/s9_a18_parked_metal.log | cut -c1-260 >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::a16_the_8b_witness_planes_in_every_form -- --ignored --exact --nocapture --test-threads=1 > $R/s9_a16_8b.log 2>&1; say "a16 8B witness planes in every form (CPU and device products, refusals) rc=$?"
grep -E "A16-8B|test result|panicked" $R/s9_a16_8b.log | grep -E "refus|variants|test result|panicked|no form|the default" | cut -c1-300 >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::a17_w16r2_rung_golden_under_every_a17_setting -- --ignored --exact --nocapture --test-threads=1 > $R/s9_a17rung.log 2>&1; say "a17 rung golden under every setting (CPU and Metal) rc=$?"
grep -E "A17-|test result|panicked" $R/s9_a17rung.log | cut -c1-240 >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 HL_PB_ORACLE=0 $C private_block::w16r2_tests::a17_the_8b_block_proves_the_same_under_every_a17_setting -- --ignored --exact --nocapture --test-threads=1 > $R/s9_a17_8b.log 2>&1; say "a17 8B block under every setting rc=$?"
grep -E "A17-|test result|panicked" $R/s9_a17_8b.log | cut -c1-240 >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::a15_the_8b_witness_planes_in_every_sealing_pool -- --ignored --exact --nocapture --test-threads=1 > $R/s9_a15_8b.log 2>&1; say "a15 8B chain in every pool (CPU and device products) rc=$?"
grep -E "test result|panicked" $R/s9_a15_8b.log | cut -c1-240 >> $P
$C private_block::range16_tests::a14_the_8b_private_slots_tables_equal_under_both_sums -- --ignored --exact --nocapture --test-threads=1 > $R/s9_lazy8b.log 2>&1; say "a14 8B private tables under both sums rc=$?"
grep -E "test result|panicked" $R/s9_lazy8b.log | cut -c1-200 >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::a14_w16r2_rung_golden_under_every_a14_setting -- --ignored --exact --nocapture --test-threads=1 > $R/s9_a14rung.log 2>&1; say "a14 rung golden under every setting rc=$?"
grep -E "test result|panicked" $R/s9_a14rung.log | cut -c1-200 >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 HL_PB_ORACLE=0 $C private_block::w16r2_tests::a14_the_8b_block_proves_the_same_under_every_a14_setting -- --ignored --exact --nocapture --test-threads=1 > $R/s9_a14_8b.log 2>&1; say "a14 8B block under every setting rc=$?"
grep -E "A14-8B|test result|panicked" $R/s9_a14_8b.log | cut -c1-200 >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::a8_w16r2_rung_golden_under_every_store_fold_form -- --ignored --exact --nocapture --test-threads=1 > $R/s9_a8rung.log 2>&1; say "a8 rung golden under every form rc=$?"
grep -E "test result|panicked" $R/s9_a8rung.log | cut -c1-200 >> $P
$C private_block::range16_tests::a12_census_and_the_device_tables_equal_the_host_tables_word_for_word -- --ignored --exact --nocapture --test-threads=1 > $R/s9_census.log 2>&1; say "a12 census + word-for-word (Metal) rc=$?"
grep -E "test result|panicked" $R/s9_census.log | cut -c1-360 >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::a12_w16r2_rung_golden_with_the_slot_tables_built_on_the_host_and_on_the_device -- --ignored --exact --nocapture --test-threads=1 > $R/s9_rung_modes.log 2>&1; say "a12 rung golden in every table mode rc=$?"
grep -E "test result|panicked" $R/s9_rung_modes.log | cut -c1-300 >> $P
$C private_block::w16r2_tests::a11_w16r2_rung_golden_inside_small_rayon_pools -- --exact --nocapture --test-threads=1 > $R/s9_pools_cpu.log 2>&1; say "a11 CPU pool byte test rc=$?"
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::a11_w16r2_rung_digests_in_per_fork_pools_on_the_device -- --ignored --exact --nocapture --test-threads=1 > $R/s9_pools_metal.log 2>&1; say "a11 Metal pool byte test rc=$?"
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::a7_w16r2_rung_digests_on_six_threads_at_one_and_at_six_queues -- --ignored --exact --nocapture --test-threads=1 > $R/s9_queues.log 2>&1; say "a7 queue byte test rc=$?"
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::w16r2_rung_cpu_and_metal_digests_equal_the_golden -- --ignored --exact --nocapture --test-threads=1 > $R/s9_r2rung.log 2>&1; say "w16r2 rung golden rc=$?"
grep -E "W16R2-RUNG-DIGEST" $R/s9_r2rung.log | cut -c1-220 >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 HL_M4_PHASES=1 HL_M4_WARM_PASSES=1 HL_M4_PROFILES=R13_SHIELD_T128_H24,R13_8B_T128_H24,W16_SHIELD_T128_H24,W16_8B_T128_H24,W16R2_SHIELD_T128_H24,W16R2_8B_T128_H24 $C $T::m4_trained_accuracy_block_cpu_and_metal_digests_and_times -- --ignored --exact --nocapture --test-threads=1 > $R/s9_trained.log 2>&1; say "trained digests rc=$?"
for d in 5a6193d3 f590b01f 79f987ef a8258241 0e88d84f 90003b76; do
  if grep -q "$d" $R/s9_trained.log; then say "digest $d present"; else say "DIGEST $d MISSING"; fi
done
if grep -q "90003b760eb7ad80" $R/s9_a18_8b.log; then say "8B core proof 90003b760eb7ad80 present (a18 8B block)"; else say "8B CORE PROOF 90003b760eb7ad80 MISSING"; fi
quiet "d55 default"
env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=2 HL_D55_SEALED=1 HL_D55_PIPE=4 $C $D -- --ignored --exact --nocapture --test-threads=1 > $R/s9_d55.log 2>&1; say "d55 default rc=$?"
seen "d55 default"
grep -E "sealing pass|verified|receipt [0-9]+ B|^D55-AB SUMMARY|^D55-AB PIPE|A15 SEALED|A15 PIPE-SEAL" $R/s9_d55.log | cut -c1-260 > $O/s9_d55.log
grep -E "^D55-AB SUMMARY|^D55-AB PIPE" $R/s9_d55.log | cut -c1-260 >> $P
quiet "production d55 default"
env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_A19_AB_PASSES=2 HL_A19_AB=default $C $K::a19_production_d55_ab -- --ignored --exact --nocapture --test-threads=1 > $R/s9_prod.log 2>&1; say "production d55 default rc=$?"
seen "production d55 default"
grep -E "^D55-AB (A19|SUMMARY)" $R/s9_prod.log | cut -c1-900 > $O/s9_prod.log
grep -E "SUMMARY|panicked|verified" $R/s9_prod.log | cut -c1-300 >> $P
say "all done"
