#!/bin/bash
# A18 stage 2, THE BYTE EVIDENCE on the work-in-progress tree (A13's split and window ported; the TABINV, REGISTRY and
# PUBTAB forms). Build; A18's suite tests (CPU: the rung digests under every form and the split core, the record's cover
# and the table forms against the old code, A13's parked forks against whole forks on every path); the D55 fork-run
# suite (every non-ignored test of run_fork_tests: the honest runs, the tamper families, A17's turncoat); the source
# audits (s24, s25, hash_domain); then on Metal: the W16R2 rung golden under every A18 setting through all three entries,
# A13's parked-fork byte test on the device under a18old and a18new, and one 8B T128 block under every setting. A line
# `BYTES FAILED` marks any failure (stage 3 refuses to run then). One guarded job, class gpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a2b8233000ecbf9ef
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$W/results/zk60_effplan_20261105/a18
F=/Users/victorrielly/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
P=$O/s2.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
fail=0
chk() { if [ "$1" -ne 0 ]; then fail=1; say "BYTES FAILED: $2"; fi; }
say start
$C --no-run > $O/raw/s2_build.log 2>&1
rc=$?
say "build rc=$rc"
if [ $rc -ne 0 ]; then
  grep -E "^error" -A 14 $O/raw/s2_build.log | head -200 >> $P
  say "BYTES FAILED: build"
  say "all done (build failed)"
  exit 1
fi
env HL_R13_LOADER_FIXTURES=$F $C a18_ -- --test-threads=4 --nocapture > $O/raw/s2_a18_suite.log 2>&1; rc=$?; say "a18 suite tests (CPU) rc=$rc"; chk $rc "a18 suite tests"
grep -E "^test |test result|A18-|panicked" $O/raw/s2_a18_suite.log | cut -c1-300 > $O/s2_a18_suite.log
grep -E "test result|panicked|^test .*FAILED" $O/s2_a18_suite.log >> $P
env HL_R13_LOADER_FIXTURES=$F $C private_block::run::fork::tests -- --test-threads=8 > $O/raw/s2_fork_suite.log 2>&1; rc=$?; say "D55 fork-run suite (non-ignored) rc=$rc"; chk $rc "fork-run suite"
grep -E "test result|panicked|FAILED" $O/raw/s2_fork_suite.log | cut -c1-240 > $O/s2_fork_suite.log
cat $O/s2_fork_suite.log >> $P
env HL_R13_LOADER_FIXTURES=$F $C -- private_block::s25_tests private_block::s24_tests private_block::hash_domain --test-threads=8 > $O/raw/s2_audits.log 2>&1; rc=$?; say "source audits (s25, s24, hash_domain) rc=$rc"; chk $rc "source audits"
grep -E "test result|panicked|FAILED" $O/raw/s2_audits.log | cut -c1-240 > $O/s2_audits.log
cat $O/s2_audits.log >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::a18_w16r2_rung_golden_under_every_a18_setting -- --ignored --exact --nocapture --test-threads=1 > $O/raw/s2_a18rung.log 2>&1; rc=$?; say "a18 rung golden under every setting (CPU and Metal, three entries) rc=$rc"; chk $rc "a18 rung golden"
grep -E "A18-|test result|panicked" $O/raw/s2_a18rung.log | cut -c1-240 > $O/s2_a18rung.log
grep -E "test result|panicked" $O/s2_a18rung.log >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::run::fork::tests::a18_parked_forks_equal_whole_forks_byte_for_byte_at_the_w16r2_rung_on_the_device -- --ignored --exact --nocapture --test-threads=1 > $O/raw/s2_a18_bytes_metal.log 2>&1; rc=$?; say "a18 parked forks = whole forks on the device (a18old, a18new) rc=$rc"; chk $rc "a18 parked forks on the device"
grep -E "A18-|test result|panicked" $O/raw/s2_a18_bytes_metal.log | cut -c1-260 > $O/s2_a18_bytes_metal.log
grep -E "test result|panicked" $O/s2_a18_bytes_metal.log >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 HL_PB_ORACLE=0 $C private_block::w16r2_tests::a18_the_8b_block_proves_the_same_under_every_a18_setting -- --ignored --exact --nocapture --test-threads=1 > $O/raw/s2_a18_8b.log 2>&1; rc=$?; say "a18 8B block under every setting rc=$rc"; chk $rc "a18 8B block"
grep -E "A18-|test result|panicked" $O/raw/s2_a18_8b.log | cut -c1-240 > $O/s2_a18_8b.log
cat $O/s2_a18_8b.log >> $P
if [ $fail -eq 0 ]; then say "BYTES PASSED"; fi
say "all done"
