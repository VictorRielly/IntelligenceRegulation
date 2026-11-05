#!/bin/bash
# A13 stage 6, FINAL ACCEPTANCE on the final tree (`check_a8merge.sh`'s list, pointed at this worktree, plus the A13
# byte tests): build; the no-feature `cargo check --tests`; the full lib suite (expect only the known three failures;
# the A13 CPU byte tests are in it); zkp-core's lib suite; the A13 Metal byte tests; the A8 rung golden under every
# store-fold form; the A12 census and rung-mode tests; the A11 pool byte tests (CPU and Metal); the A7 queue byte
# test; the W16R2 rung golden and the six post-F12 digests under HL_GPU_REQUIRED=1; the D55 harness on the default
# (HL_D55_AHEAD unset: off), sealed one request and a 4-request stream, every receipt verified; and the same with
# HL_D55_AHEAD=32 (every receipt verified, the same sizes). One guarded job, class gpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-afed131c59aa694b5
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
Z=$W/ops/zkp-mvp/gpu-metal/zkp-core/Cargo.toml
O=$W/results/zk60_effplan_20261105/a13
F=/Users/victorrielly/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
T=private_block::slot_ir::accuracy::tests
D=private_block::run::fork::tests::d55_ab_one_request_serial_against_forks
P=$O/s6.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$C --no-run > $O/s6_build.log 2>&1; say "build rc=$?"
/opt/homebrew/bin/cargo check --tests --offline --locked --manifest-path $H > $O/s6_check_nometal.log 2>&1; say "no-feature cargo check --tests rc=$?"
env HL_R13_LOADER_FIXTURES=$F $C -- --test-threads=8 > $O/s6_full.log 2>&1; say "full lib suite rc=$? (expect failures: exactly the known three)"
grep -E "^test result|^    [a-z_:0-9]+$" $O/s6_full.log | tail -8 >> $P
grep -E "a13_|a12_the_device_table_formula|a8_store_fold_forms_equal" $O/s6_full.log | cut -c1-200 >> $P
/opt/homebrew/bin/cargo test --release --offline --locked --manifest-path $Z --lib > $O/s6_zkpcore.log 2>&1; say "zkp-core lib tests rc=$?"
grep -E "test result" $O/s6_zkpcore.log >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::a13_w16r2_rung_golden_with_the_core_split_across_threads_on_the_device -- --ignored --exact --nocapture --test-threads=1 > $O/s6_a13split_metal.log 2>&1; say "a13 split core golden (Metal) rc=$?"
grep -E "A13-SPLIT|test result|panicked" $O/s6_a13split_metal.log | cut -c1-260 >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::run::fork::a13_tests::a13_parked_forks_equal_whole_forks_byte_for_byte_at_the_w16r2_rung_on_the_device -- --ignored --exact --nocapture --test-threads=1 > $O/s6_a13bytes_metal.log 2>&1; say "a13 fork byte test (Metal) rc=$?"
grep -E "A13-BYTES \(Metal\) W16R2_RUNG_H24 L4: |A13-BYTES \(Metal\): |test result|panicked" $O/s6_a13bytes_metal.log | cut -c1-260 >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::a8_w16r2_rung_golden_under_every_store_fold_form -- --ignored --exact --nocapture --test-threads=1 > $O/s6_a8rung.log 2>&1; say "a8 rung golden under every form rc=$?"
grep -E "A8-RUNG|test result|panicked" $O/s6_a8rung.log | cut -c1-200 >> $P
$C private_block::range16_tests::a12_census_and_the_device_tables_equal_the_host_tables_word_for_word -- --ignored --exact --nocapture --test-threads=1 > $O/s6_census.log 2>&1; say "a12 census + word-for-word (Metal) rc=$?"
grep -E "A12-CENSUS [^ ]+: |test result|panicked" $O/s6_census.log | cut -c1-360 >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::a12_w16r2_rung_golden_with_the_slot_tables_built_on_the_host_and_on_the_device -- --ignored --exact --nocapture --test-threads=1 > $O/s6_rung_modes.log 2>&1; say "a12 rung golden in every table mode rc=$?"
grep -E "A12-TABLES|test result|panicked" $O/s6_rung_modes.log | cut -c1-300 >> $P
$C private_block::w16r2_tests::a11_w16r2_rung_golden_inside_small_rayon_pools -- --exact --nocapture --test-threads=1 > $O/s6_pools_cpu.log 2>&1; say "a11 CPU pool byte test rc=$?"
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::a11_w16r2_rung_digests_in_per_fork_pools_on_the_device -- --ignored --exact --nocapture --test-threads=1 > $O/s6_pools_metal.log 2>&1; say "a11 Metal pool byte test rc=$?"
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::a7_w16r2_rung_digests_on_six_threads_at_one_and_at_six_queues -- --ignored --exact --nocapture --test-threads=1 > $O/s6_queues.log 2>&1; say "a7 queue byte test rc=$?"
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::w16r2_rung_cpu_and_metal_digests_equal_the_golden -- --ignored --exact --nocapture --test-threads=1 > $O/s6_r2rung.log 2>&1; say "w16r2 rung golden rc=$?"
grep -E "W16R2-RUNG-DIGEST" $O/s6_r2rung.log | cut -c1-220 >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 HL_M4_PHASES=1 HL_M4_WARM_PASSES=1 HL_M4_PROFILES=R13_SHIELD_T128_H24,R13_8B_T128_H24,W16_SHIELD_T128_H24,W16_8B_T128_H24,W16R2_SHIELD_T128_H24,W16R2_8B_T128_H24 $C $T::m4_trained_accuracy_block_cpu_and_metal_digests_and_times -- --ignored --exact --nocapture --test-threads=1 > $O/s6_trained.log 2>&1; say "trained digests rc=$?"
for d in 5a6193d3 f590b01f 79f987ef a8258241 0e88d84f 90003b76; do
  if grep -q "$d" $O/s6_trained.log; then say "digest $d present"; else say "DIGEST $d MISSING"; fi
done
env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=2 HL_D55_SEALED=1 HL_D55_PIPE=4 $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/s6_d55.log 2>&1; say "d55 default (ahead off) rc=$?"
grep -E "verified|^D55-AB SUMMARY|^D55-AB PIPE|receipt [0-9]+ B|^D55-AB A13 SEALED" $O/s6_d55.log | cut -c1-300 >> $P
env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_AHEAD=32 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=1 HL_D55_SEALED=1 HL_D55_PIPE=4 $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/s6_d55_ahead32.log 2>&1; say "d55 with HL_D55_AHEAD=32 rc=$?"
grep -E "verified|^D55-AB SUMMARY|^D55-AB PIPE|SEALED pass|^D55-AB A13 SEALED" $O/s6_d55_ahead32.log | cut -c1-300 >> $P
say "all done"
