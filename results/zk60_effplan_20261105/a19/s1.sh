#!/bin/bash
# A19 stage 1, the byte evidence on the work-in-progress tree. Build; A19's suite tests (the planned path and its
# controls at the W16R2 rung; production's D55 path at the R13 rung, the window off and on, the blocks shared and
# reloaded, a refused chain); A18's parked-forks test; the D55 fork-run suite (the honest runs, the tamper families,
# the D60 CLI tests through stack-prove --d55-workers); the trained-stack CLI tests (D12a's stack-prove, whose code
# moved); then on the Metal device: A19's two device tests and A18's. One guarded job, class gpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a1f45d632690f8326
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$W/results/zk60_effplan_20261105/a19
F=/Users/victorrielly/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
K=private_block::run::fork::tests
P=$O/s1.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$C --no-run > $O/raw/s1_build.log 2>&1
rc=$?
say "build rc=$rc"
if [ $rc -ne 0 ]; then
  grep -E "^error" -A 14 $O/raw/s1_build.log | head -200 >> $P
  say "all done (build failed)"
  exit 1
fi
env HL_R13_LOADER_FIXTURES=$F $C $K::a19_ -- --nocapture --test-threads=2 > $O/raw/s1_a19_suite.log 2>&1; say "A19 suite tests (CPU) rc=$?"
grep -E "A19-|test result|panicked|FAILED" $O/raw/s1_a19_suite.log | cut -c1-400 >> $P
env HL_R13_LOADER_FIXTURES=$F $C $K::a18_parked_forks_equal_whole_forks_byte_for_byte_at_the_w16r2_rung -- --exact --nocapture --test-threads=1 > $O/raw/s1_a18_parked.log 2>&1; say "A18 parked forks = whole forks (CPU) rc=$?"
grep -E "test result|panicked" $O/raw/s1_a18_parked.log | cut -c1-240 >> $P
env HL_R13_LOADER_FIXTURES=$F $C $K:: -- --test-threads=4 > $O/raw/s1_fork_suite.log 2>&1; say "the D55 fork-run suite (CPU) rc=$?"
grep -E "^test result|^    [a-z_:0-9]+$|panicked" $O/raw/s1_fork_suite.log | tail -12 >> $P
env HL_R13_LOADER_FIXTURES=$F $C private_block::trained_stack_tests:: -- --test-threads=4 > $O/raw/s1_trained_stack.log 2>&1; say "the trained-stack CLI tests rc=$? (expect the one known failure: review_n_r6_b_a_stale_statement_writing_dir_is_removed_or_refused_by_name)"
grep -E "^test result|^    [a-z_:0-9]+$|panicked" $O/raw/s1_trained_stack.log | tail -8 >> $P
env HL_R13_LOADER_FIXTURES=$F HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C $K::a19_planned_parts_equal_whole_forks_and_every_control_refuses_at_the_w16r2_rung_on_the_device -- --ignored --exact --nocapture --test-threads=1 > $O/raw/s1_a19_planned_metal.log 2>&1; say "A19 planned path + controls on the device rc=$?"
grep -E "A19-|test result|panicked" $O/raw/s1_a19_planned_metal.log | cut -c1-400 >> $P
env HL_R13_LOADER_FIXTURES=$F HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C $K::a19_production_d55_path_window_on_and_off_and_a_refused_chain_at_the_r13_rung_on_the_device -- --ignored --exact --nocapture --test-threads=1 > $O/raw/s1_a19_prod_metal.log 2>&1; say "A19 production path on the device rc=$?"
grep -E "A19-|test result|panicked" $O/raw/s1_a19_prod_metal.log | cut -c1-400 >> $P
env HL_R13_LOADER_FIXTURES=$F HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C $K::a18_parked_forks_equal_whole_forks_byte_for_byte_at_the_w16r2_rung_on_the_device -- --ignored --exact --nocapture --test-threads=1 > $O/raw/s1_a18_parked_metal.log 2>&1; say "A18 parked forks = whole forks on the device rc=$?"
grep -E "test result|panicked" $O/raw/s1_a18_parked_metal.log | cut -c1-240 >> $P
say "all done"
