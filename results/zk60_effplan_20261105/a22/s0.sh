#!/bin/bash
# A22 stage 0: compile and the quick CPU checks. A type check of the test build (gpu-metal) and of the no-feature
# test build; the production (non-test) library build and the CLI example; the test build; then A22's suite tests on
# the CPU (the R13 export through the server, the synthetic rung stream, CS-6 with the digests ahead) and the source
# audits A22's edits could move (R6's sealing-pass audit, s25's hash call-site census and file census, the absorb
# label scan, A19's and A20's suite tests of production's D55 path). One guarded job.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a75997b3d20d4ca57
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$W/results/zk60_effplan_20261105/a22
F=/Users/victorrielly/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
K=private_block::run::fork::tests
P=$O/s0.progress
R=$O/raw
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
/opt/homebrew/bin/cargo check --tests --release --offline --locked --features gpu-metal --manifest-path $H --lib -j 8 > $R/s0_check.log 2>&1
rc=$?
say "cargo check --tests (gpu-metal) rc=$rc"
if [ $rc -ne 0 ]; then
  grep -E "^error" -A 16 $R/s0_check.log | head -240 >> $P
  say "all done (check failed)"
  exit 1
fi
say "check warnings in A22's files: $(grep -A 3 '^warning' $R/s0_check.log | grep -cE 'trained_block.rs|run_fork.rs|run_fork_tests.rs|zk60_trained_block.rs')"
grep -A 6 '^warning' $R/s0_check.log | grep -E 'trained_block.rs|run_fork.rs|run_fork_tests.rs' -B 6 | head -60 >> $P
/opt/homebrew/bin/cargo check --tests --offline --locked --manifest-path $H > $R/s0_check_nometal.log 2>&1; rc=$?; say "no-feature cargo check --tests rc=$rc"
if [ $rc -ne 0 ]; then grep -E "^error" -A 16 $R/s0_check_nometal.log | head -120 >> $P; fi
/opt/homebrew/bin/cargo build --release --offline --locked --features gpu-metal --manifest-path $H --lib > $R/s0_build_prod.log 2>&1; rc=$?; say "production library build (non-test, gpu-metal) rc=$rc"
say "non-test warnings in trained_block.rs / run_fork.rs: $(grep -A 3 '^warning' $R/s0_build_prod.log | grep -cE 'trained_block.rs|run_fork.rs')"
grep -A 3 '^warning' $R/s0_build_prod.log | grep -E 'trained_block.rs|run_fork.rs' -B 3 | grep '^warning' >> $P
/opt/homebrew/bin/cargo build --release --offline --locked --features gpu-metal --manifest-path $H --example zk60_trained_block > $R/s0_build_cli.log 2>&1; say "the CLI example zk60_trained_block (stack-serve) rc=$?"
$C --no-run > $R/s0_build.log 2>&1
rc=$?
say "test build rc=$rc"
if [ $rc -ne 0 ]; then
  grep -E "^error" -A 16 $R/s0_build.log | head -200 >> $P
  say "all done (test build failed)"
  exit 1
fi
for t in $K::a22::a22_cs6_takes_the_digest_kept_with_its_block_and_refuses_a_wrong_one $K::a22::a22_the_resident_synthetic_rung_stream_replays_with_the_window_off_and_on $K::a22::a22_the_server_proves_the_r13_export_as_stack_prove_does_and_carries_on_after_every_refusal; do
  n=${t##*::}
  env HL_R13_LOADER_FIXTURES=$F $C $t -- --exact --nocapture --test-threads=1 > $R/s0_$n.log 2>&1; say "$n rc=$?"
  grep -E "^A22-|test result|panicked" $R/s0_$n.log | cut -c1-700 >> $P
done
env HL_R13_LOADER_FIXTURES=$F $C -- r6_tests::the_sealing_pass s25_tests::every_hash_call_site s25_tests::r19b_every_rs_file every_absorb_label_on_the_path_is_in_the_table d60_f3 d60_f8 $K::a19_ $K::a20_ --test-threads=4 > $R/s0_audits.log 2>&1; say "the audits and A19's / A20's suite tests rc=$?"
grep -E "^test .*(ok|FAILED|ignored)$|test result|panicked" $R/s0_audits.log | cut -c1-240 >> $P
say "all done"
