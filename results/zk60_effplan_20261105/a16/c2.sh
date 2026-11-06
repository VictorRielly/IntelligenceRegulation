#!/bin/bash
# A16 stage c2 (c1 again, with A16_KERNELS and the refusal variants), COMPILE AND CORRECTNESS FIRST: build the test binary (gpu-metal); the no-feature
# `cargo check --tests`; the A16 unit and suite tests (the fallbacks' refusal order, every form
# against the builder before A16 at the rungs and TinyLlama T128, the rung chain in every form
# and pool), H124c's parallel-against-sequential test (six profiles, the 8B among them, in the
# default forms), A4's device-against-CPU test and A15's rung test. One guarded job, class gpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a25af4fbe05476b8b
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$W/results/zk60_effplan_20261105/a16
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
P=$O/c2.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
mkdir -p $O/raw
$C --no-run > $O/raw/c2_build.log 2>&1
rc=$?
say "build rc=$rc"
if [ $rc -ne 0 ]; then
  grep -E "^(error|warning)" -A 14 $O/raw/c2_build.log | head -200 >> $P
  say "all done (build failed)"
  exit 1
fi
grep -E "^warning" -A 8 $O/raw/c2_build.log | head -60 >> $P
/opt/homebrew/bin/cargo check --tests --offline --locked --manifest-path $H > $O/raw/c2_check_nometal.log 2>&1
rc=$?
say "no-feature cargo check --tests rc=$rc"
if [ $rc -ne 0 ]; then
  grep -E "^error" -A 14 $O/raw/c2_check_nometal.log | head -80 >> $P
fi
$C private_block::witness::accuracy::tests:: -- --nocapture --test-threads=4 > $O/raw/c2_unit.log 2>&1
say "witness_accuracy unit tests rc=$?"
grep -E "^test |test result|panicked" $O/raw/c2_unit.log | cut -c1-240 >> $P
$C private_block::w16r2_tests::a16_ -- --nocapture --test-threads=2 > $O/raw/c2_a16.log 2>&1
say "a16 suite tests rc=$?"
grep -E "A16-|^test |test result|panicked" $O/raw/c2_a16.log | cut -c1-300 >> $P
$C private_block::witness_speed_tests:: -- --nocapture --test-threads=2 > $O/raw/c2_speed.log 2>&1
say "witness_speed_tests (H124c, A4) rc=$?"
grep -E "H124c|A4 |^test |test result|panicked" $O/raw/c2_speed.log | cut -c1-240 >> $P
$C private_block::w16r2_tests::a15_the_seal_pool_rule_and_the_rung_witness_planes_in_every_pool -- --exact --nocapture --test-threads=1 > $O/raw/c2_a15rung.log 2>&1
say "a15 rung test rc=$?"
grep -E "test result|panicked" $O/raw/c2_a15rung.log | cut -c1-240 >> $P
say "all done"
