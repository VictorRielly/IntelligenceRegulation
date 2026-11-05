#!/bin/bash
# A13 stage 5: the byte tests again after the fix of a stale count in `run_fork_a13_tests.rs` (stage 4 found that
# with the lazy hand-back, one request's form takes back whole the parts not started when the forks run, so fewer
# forks are parked than the window: the test now counts parked + taken back). Build; the CPU and Metal fork byte
# tests; the split-core goldens. One guarded job, class gpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-afed131c59aa694b5
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$W/results/zk60_effplan_20261105/a13
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
P=$O/s5.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$C --no-run > $O/s5_build.log 2>&1
rc=$?
say "build rc=$rc"
if [ $rc -ne 0 ]; then
  say "all done (build failed)"
  exit 1
fi
$C private_block::run::fork::a13_tests::a13_parked_forks_equal_whole_forks_byte_for_byte_at_the_w16r2_rung -- --exact --nocapture --test-threads=1 > $O/s5_bytes_cpu.log 2>&1; say "a13 fork byte test (CPU) rc=$?"
grep -E "test result|panicked|left|right" $O/s5_bytes_cpu.log | cut -c1-300 >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::run::fork::a13_tests::a13_parked_forks_equal_whole_forks_byte_for_byte_at_the_w16r2_rung_on_the_device -- --ignored --exact --nocapture --test-threads=1 > $O/s5_bytes_metal.log 2>&1; say "a13 fork byte test (Metal) rc=$?"
grep -E "test result|panicked|left|right" $O/s5_bytes_metal.log | cut -c1-300 >> $P
$C private_block::w16r2_tests::a13_w16r2_rung_golden_with_the_core_split_across_threads -- --exact --nocapture --test-threads=1 > $O/s5_split_cpu.log 2>&1; say "a13 split core golden (CPU) rc=$?"
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::a13_w16r2_rung_golden_with_the_core_split_across_threads_on_the_device -- --ignored --exact --nocapture --test-threads=1 > $O/s5_split_metal.log 2>&1; say "a13 split core golden (Metal) rc=$?"
grep -E "A13-SPLIT|test result|panicked" $O/s5_split_cpu.log $O/s5_split_metal.log | cut -c1-260 >> $P
say "all done"
