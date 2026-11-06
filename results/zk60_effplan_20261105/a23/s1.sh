#!/bin/bash
# A23 stage 1: compile, the quick CPU checks and the byte tests. A type check of the test build (gpu-metal) and of the
# no-feature test build; the production (non-test) library build and the CLI example; the test build; then A23's suite
# tests on the CPU (CS-6 and CS-1 / CS-4 on shared kept blocks, the R13 export through the server with the blocks
# shared and copied, the resident synthetic rung with the blocks shared at the default budget and at 0, a wrong kept
# digest in a running server), A22's suite tests (the same server code at the defaults), the source audits A23's edits
# could move (R6's sealing-pass audit, s25's hash call-site census and file census, the absorb label scan, D60 F3 / F8,
# A19's and A20's suite tests of production's D55 path); then A23's and A22's device tests (the R13 export through the
# server, the resident synthetic rung, the resident 8B stack). One guarded job.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a34b7617369662958
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$W/results/zk60_effplan_20261105/a23
F=/Users/victorrielly/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
K=private_block::run::fork::tests
P=$O/s1.progress
R=$O/raw
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
# the dependencies' build cache: a copy-on-write clone of A22's finished lane's target directory (APFS), if this
# worktree has none yet (hashline itself is rebuilt: its fingerprints name this worktree's paths)
T=$W/ops/zkp-mvp/gpu-metal/hashline/target
S=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a75997b3d20d4ca57/ops/zkp-mvp/gpu-metal/hashline/target
if [ ! -d $T ] && [ -d $S ]; then cp -c -R $S $T > $R/s1_clone.log 2>&1; say "target clone rc=$?"; fi
/opt/homebrew/bin/cargo check --tests --release --offline --locked --features gpu-metal --manifest-path $H --lib -j 8 > $R/s1_check.log 2>&1
rc=$?
say "cargo check --tests (gpu-metal) rc=$rc"
if [ $rc -ne 0 ]; then
  grep -E "^error" -A 16 $R/s1_check.log | head -300 >> $P
  say "all done (check failed)"
  exit 1
fi
say "check warnings in A23's files: $(grep -A 3 '^warning' $R/s1_check.log | grep -cE 'trained_block.rs|run_fork.rs|run_fork_tests.rs|protocol.rs')"
grep -A 6 '^warning' $R/s1_check.log | grep -E 'trained_block.rs|run_fork.rs|run_fork_tests.rs|protocol.rs' -B 6 | grep -E '^warning|-->' | head -40 >> $P
/opt/homebrew/bin/cargo check --tests --offline --locked --manifest-path $H > $R/s1_check_nometal.log 2>&1; rc=$?; say "no-feature cargo check --tests rc=$rc"
if [ $rc -ne 0 ]; then grep -E "^error" -A 16 $R/s1_check_nometal.log | head -120 >> $P; fi
/opt/homebrew/bin/cargo build --release --offline --locked --features gpu-metal --manifest-path $H --lib > $R/s1_build_prod.log 2>&1; rc=$?; say "production library build (non-test, gpu-metal) rc=$rc"
say "non-test warnings in trained_block.rs / run_fork.rs / protocol.rs: $(grep -A 3 '^warning' $R/s1_build_prod.log | grep -cE 'trained_block.rs|run_fork.rs|protocol.rs')"
grep -A 3 '^warning' $R/s1_build_prod.log | grep -E 'trained_block.rs|run_fork.rs|protocol.rs' -B 3 | grep '^warning' >> $P
/opt/homebrew/bin/cargo build --release --offline --locked --features gpu-metal --manifest-path $H --example zk60_trained_block > $R/s1_build_cli.log 2>&1; say "the CLI example zk60_trained_block (stack-serve) rc=$?"
$C --no-run > $R/s1_build.log 2>&1
rc=$?
say "test build rc=$rc"
if [ $rc -ne 0 ]; then
  grep -E "^error" -A 16 $R/s1_build.log | head -200 >> $P
  say "all done (test build failed)"
  exit 1
fi
for t in a23::a23_cs6_and_cs1_cs4_take_a_shared_blocks_startup_record_and_a_wrong_digest_is_refused a23::a23_a_wrong_kept_digest_in_a_running_server_is_refused_by_cs6_and_the_stream_carries_on a23::a23_the_resident_synthetic_rung_stream_with_shared_blocks_replays a23::a23_the_server_with_shared_blocks_proves_the_r13_export_as_stack_prove_does a22::a22_cs6_takes_the_digest_kept_with_its_block_and_refuses_a_wrong_one a22::a22_the_resident_synthetic_rung_stream_replays_with_the_window_off_and_on a22::a22_the_server_proves_the_r13_export_as_stack_prove_does_and_carries_on_after_every_refusal; do
  n=${t##*::}
  env HL_R13_LOADER_FIXTURES=$F $C $K::$t -- --exact --nocapture --test-threads=1 > $R/s1_$n.log 2>&1; say "$n rc=$?"
  grep -E "^A2[23]-|test result|panicked" $R/s1_$n.log | cut -c1-900 >> $P
done
env HL_R13_LOADER_FIXTURES=$F $C -- r6_tests::the_sealing_pass s25_tests::every_hash_call_site s25_tests::r19b_every_rs_file every_absorb_label_on_the_path_is_in_the_table d60_f3 d60_f8 $K::a19_ $K::a20_ $K::a21_ --test-threads=4 > $R/s1_audits.log 2>&1; say "the audits and A19's / A20's / A21's suite tests rc=$?"
grep -E "^test .*(ok|FAILED|ignored)$|test result|panicked" $R/s1_audits.log | cut -c1-240 >> $P
for t in a23::a23_the_server_with_shared_blocks_proves_the_r13_export_as_stack_prove_does_on_the_device a23::a23_the_resident_synthetic_rung_stream_with_shared_blocks_replays_on_the_device a22::a22_the_server_proves_the_r13_export_as_stack_prove_does_and_carries_on_after_every_refusal_on_the_device a22::a22_the_resident_synthetic_rung_stream_replays_with_the_window_off_and_on_on_the_device; do
  n=${t##*::}
  env HL_R13_LOADER_FIXTURES=$F HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C $K::$t -- --ignored --exact --nocapture --test-threads=1 > $R/s1_$n.log 2>&1; say "$n rc=$?"
  grep -E "^A2[23]-|test result|panicked" $R/s1_$n.log | cut -c1-900 >> $P
done
for t in a23::a23_the_resident_8b_stream_with_shared_blocks_replays a22::a22_the_resident_8b_stream_replays; do
  n=${t##*::}
  env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 HL_PB_ORACLE=0 $C $K::$t -- --ignored --exact --nocapture --test-threads=1 > $R/s1_$n.log 2>&1; say "$n rc=$?"
  grep -E "^A2[23]-|test result|panicked" $R/s1_$n.log | cut -c1-900 >> $P
done
say "all done"
