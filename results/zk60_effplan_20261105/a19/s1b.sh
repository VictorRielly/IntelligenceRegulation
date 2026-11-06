#!/bin/bash
# A19 stage 1b: stage 1's planned-path test again after the control fix (stage 0's two reserved pairs are the same
# row, so the IO-row control swaps stage 1's), on the CPU and on the Metal device. One guarded job, class gpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a1f45d632690f8326
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$W/results/zk60_effplan_20261105/a19
F=/Users/victorrielly/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
K=private_block::run::fork::tests
P=$O/s1b.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$C --no-run > $O/raw/s1b_build.log 2>&1
rc=$?
say "build rc=$rc"
if [ $rc -ne 0 ]; then
  grep -E "^error" -A 14 $O/raw/s1b_build.log | head -200 >> $P
  say "all done (build failed)"
  exit 1
fi
env HL_R13_LOADER_FIXTURES=$F $C $K::a19_planned_parts_equal_whole_forks_and_every_control_refuses_at_the_w16r2_rung -- --exact --nocapture --test-threads=1 > $O/raw/s1b_a19_planned.log 2>&1; say "A19 planned path + controls (CPU) rc=$?"
grep -E "A19-|test result|panicked" $O/raw/s1b_a19_planned.log | cut -c1-400 >> $P
env HL_R13_LOADER_FIXTURES=$F HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C $K::a19_planned_parts_equal_whole_forks_and_every_control_refuses_at_the_w16r2_rung_on_the_device -- --ignored --exact --nocapture --test-threads=1 > $O/raw/s1b_a19_planned_metal.log 2>&1; say "A19 planned path + controls on the device rc=$?"
grep -E "A19-|test result|panicked" $O/raw/s1b_a19_planned_metal.log | cut -c1-400 >> $P
say "all done"
