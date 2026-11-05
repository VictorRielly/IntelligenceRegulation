#!/bin/bash
# A17 stage 2, THE BYTE EVIDENCE (first pass on the new code): build; the no-feature `cargo check --tests`; the A17
# suite tests (the rung digests with kept matrices, the record tests, the turncoat fork run) and the fork-run suite
# tests; the ignored rung golden under every A17 setting (CPU and Metal) and the 8B block under every setting. One
# guarded job, class gpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a712d6f342b57b528
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$W/results/zk60_effplan_20261105/a17
F=/Users/victorrielly/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
P=$O/s2.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
mkdir -p $O/raw
$C --no-run > $O/raw/s2_build.log 2>&1
rc=$?
say "build rc=$rc"
if [ $rc -ne 0 ]; then
  grep -E "^(error|warning)" -A 14 $O/raw/s2_build.log | head -150 >> $P
  say "all done (build failed)"
  exit 1
fi
grep -E "^warning" -A 8 $O/raw/s2_build.log | head -60 >> $P
/opt/homebrew/bin/cargo check --tests --offline --locked --manifest-path $H > $O/raw/s2_check_nometal.log 2>&1
rc=$?
say "no-feature cargo check --tests rc=$rc"
if [ $rc -ne 0 ]; then
  grep -E "^error" -A 14 $O/raw/s2_check_nometal.log | head -80 >> $P
fi
env HL_R13_LOADER_FIXTURES=$F $C a17_ -- --nocapture --test-threads=1 > $O/raw/s2_a17_suite.log 2>&1
say "a17 suite tests rc=$?"
grep -E "^A17|^test |test result|panicked" $O/raw/s2_a17_suite.log | cut -c1-260 >> $P
env HL_R13_LOADER_FIXTURES=$F $C run::fork::tests:: -- --test-threads=4 > $O/raw/s2_fork_suite.log 2>&1
say "fork-run suite tests rc=$?"
grep -E "test result|FAILED|panicked" $O/raw/s2_fork_suite.log | cut -c1-260 >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::a17_w16r2_rung_golden_under_every_a17_setting -- --ignored --exact --nocapture --test-threads=1 > $O/raw/s2_a17rung.log 2>&1
say "a17 rung golden under every setting (CPU and Metal) rc=$?"
grep -E "A17-|test result|panicked" $O/raw/s2_a17rung.log | cut -c1-260 >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 HL_PB_ORACLE=0 $C private_block::w16r2_tests::a17_the_8b_block_proves_the_same_under_every_a17_setting -- --ignored --exact --nocapture --test-threads=1 > $O/raw/s2_a17_8b.log 2>&1
say "a17 8B block under every setting rc=$?"
grep -E "A17-|test result|panicked" $O/raw/s2_a17_8b.log | cut -c1-260 >> $P
say "all done"
