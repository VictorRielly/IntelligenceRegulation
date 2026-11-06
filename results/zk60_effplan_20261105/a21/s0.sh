#!/bin/bash
# A21 stage 0: a type check of the test build (fail fast), the release test build, A21's suite tests (SHA-256 against
# sha2, the block digest by the tree, the records, the sealing pass and its refusals, production's path at the R13 rung
# on the CPU), the suites the forms touch (s25's census, hash_domain's label scan, R6's sealing-pass audit, the D55
# fork-run suite), the no-feature `cargo check --tests` and the production (non-test) library build. CPU only.
# One guarded job, class cpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-accc7730ca1479119
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$W/results/zk60_effplan_20261105/a21
R=$O/raw
F=/Users/victorrielly/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
K=private_block::run::fork::tests
P=$O/s0.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
/opt/homebrew/bin/cargo check --tests --release --offline --locked --features gpu-metal --manifest-path $H --lib > $R/s0_check.log 2>&1
rc=$?
say "type check of the test build rc=$rc"
if [ $rc -ne 0 ]; then
  grep -E "^error" -A 14 $R/s0_check.log | head -200 >> $P
  say "all done (type check failed)"
  exit 1
fi
grep -E "^warning" -A 6 $R/s0_check.log | grep -E "run_sink.rs|private_block.rs|trained_statement.rs|trained_block.rs|run_fork.rs|run_fork_tests.rs|s25_tests.rs" -B 3 | head -60 >> $P
$C --no-run > $R/s0_build.log 2>&1
rc=$?
say "build rc=$rc"
if [ $rc -ne 0 ]; then
  grep -E "^error" -A 14 $R/s0_build.log | head -160 >> $P
  say "all done (build failed)"
  exit 1
fi
env HL_R13_LOADER_FIXTURES=$F $C $K::a21_ -- --nocapture --test-threads=1 > $R/s0_a21_suite.log 2>&1; say "A21 suite tests (nocapture) rc=$?"
grep -E "A21-|test result|panicked|^test " $R/s0_a21_suite.log | cut -c1-600 >> $P
for t in private_block::s25_tests private_block::hash_domain_tests private_block::r6_tests "$K"; do
  n=$(echo $t | sed 's/.*:://')
  env HL_R13_LOADER_FIXTURES=$F $C $t -- --test-threads=6 > $R/s0_suite_$n.log 2>&1; say "suite $t rc=$?"
  grep -E "^test result|^    [a-z_:0-9]+$|panicked" $R/s0_suite_$n.log | cut -c1-300 | tail -12 >> $P
done
/opt/homebrew/bin/cargo check --tests --offline --locked --manifest-path $H > $R/s0_check_nometal.log 2>&1; say "no-feature cargo check --tests rc=$?"
grep -E "^error" -A 10 $R/s0_check_nometal.log | head -60 >> $P
/opt/homebrew/bin/cargo build --release --offline --locked --features gpu-metal --manifest-path $H --lib > $R/s0_build_prod.log 2>&1; say "production library build (non-test, gpu-metal) rc=$?"
grep -A 3 '^warning' $R/s0_build_prod.log | grep -E 'run_sink.rs|private_block.rs|trained_statement.rs|trained_block.rs|run_fork.rs' -B 3 | grep -E '^warning|-->' >> $P
say "all done"
