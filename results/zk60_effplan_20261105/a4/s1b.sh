#!/bin/bash
# A4 stage 1b (finer device phases, fair CPU operands): build the lib tests (gpu-metal), run the witness product tests (CPU equality, the new device
# equality and refusal tests, the whole-witness plane equality on both device routes), then the A4 timer alone.
# Run as ONE guarded job of class gpu by run_stage.py.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a183d3e509aa57c38
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$W/results/zk60_effplan_20261105/a4
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
P=$O/s1b.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$C --no-run > $O/s1b_build.log 2>&1; rc=$?; say "build rc=$rc ($(grep -c '^warning' $O/s1b_build.log) warning lines)"
if [ $rc -ne 0 ]; then say "all done (build failed)"; exit $rc; fi
$C private_block::witness_speed_tests -- --test-threads=8 > $O/s1b_tests.log 2>&1; say "witness_speed_tests rc=$? $(grep -E '^test result' $O/s1b_tests.log | head -1)"
grep -E "^test .*(FAILED|ok)$|panicked" $O/s1b_tests.log | grep -v " ok$" >> $P
$C private_block::witness_speed_tests::a4::a4_the_device_builder_equals_the_cpu_one_on_every_plane -- --exact --nocapture --test-threads=1 > $O/s1b_planes.log 2>&1; say "plane equality rc=$?"
grep -oE "A4 .*" $O/s1b_planes.log >> $P
$C private_block::witness_speed_tests::a4::a4_witness_time_per_block_cpu_against_the_device -- --ignored --exact --nocapture --test-threads=1 > $O/s1b_timer.log 2>&1; say "A4 timer rc=$?"
grep -oE "A4 .*" $O/s1b_timer.log >> $P
say "all done"
