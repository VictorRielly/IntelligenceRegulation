#!/bin/bash
# A19 stage 10, the acceptance's suite again on the final tree. Stage 9's full suite found a fourth failure: R6's source
# audit (`r6_tests::the_sealing_pass_lookup_miss_check_refuses_by_the_cs3_name`) read the CS-3 check in the text of
# `fn seal_and_record(`, whose body is now `seal_chain`; the audit now reads `seal_chain` and checks that D12a's and
# the D55 path's entries both run it. And `prove_run_with_forks` (now reached in production through `Planned::prove`)
# carries a dead-code attribute for the non-test build. Build; the no-feature check; the full lib suite (expect exactly
# the known three); R6's audit by name; the non-test library build's warnings in this lane's files. One guarded job.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a1f45d632690f8326
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$W/results/zk60_effplan_20261105/a19
R=$O/raw
F=/Users/victorrielly/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
P=$O/s10.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$C --no-run > $R/s10_build.log 2>&1
rc=$?
say "build rc=$rc"
if [ $rc -ne 0 ]; then
  grep -E "^error" -A 14 $R/s10_build.log | head -120 >> $P
  say "all done (build failed)"
  exit 1
fi
/opt/homebrew/bin/cargo check --tests --offline --locked --manifest-path $H > $R/s10_check_nometal.log 2>&1; say "no-feature cargo check --tests rc=$?"
env HL_R13_LOADER_FIXTURES=$F $C -- --test-threads=8 > $R/s10_full.log 2>&1; say "full lib suite rc=$? (expect failures: exactly the known three)"
grep -E "^test result|^    [a-z_:0-9]+$" $R/s10_full.log | tail -8 >> $P
grep -E "a19_|r6_tests::the_sealing_pass|d60_f3|d60_f8" $R/s10_full.log | cut -c1-200 >> $P
$C private_block::r6_tests::the_sealing_pass_lookup_miss_check_refuses_by_the_cs3_name -- --exact --nocapture --test-threads=1 > $R/s10_r6.log 2>&1; say "R6's sealing-pass audit rc=$?"
/opt/homebrew/bin/cargo build --release --offline --locked --features gpu-metal --manifest-path $H --lib > $R/s10_build_prod.log 2>&1; say "production library build (non-test, gpu-metal) rc=$?"
say "warnings in run_fork.rs / trained_block.rs (non-test build): $(grep -A 3 '^warning' $R/s10_build_prod.log | grep -cE 'run_fork.rs|trained_block.rs')"
grep -A 3 '^warning' $R/s10_build_prod.log | grep -E 'run_fork.rs|trained_block.rs' -B 3 | grep '^warning' >> $P
say "all done"
