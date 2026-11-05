#!/bin/bash
# A14 stage 2, THE BYTE EVIDENCE: zkp-core's lib tests (the lane XOF against block_bytes, fill_fp in either XOF
# form, the parallel absorb against the serial digest); the no-feature `cargo check --tests`; the gpu-metal build;
# the CPU word-for-word test of the lazy sums (the rung, in the suite); the 8B private slots' tables under both sums
# (ignored); the W16R2 rung golden under every A14 setting, CPU and Metal; one 8B block's core proof under every A14
# setting (the 8B digest unchanged). One guarded job, class gpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a9838ab349101784d
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
Z=$W/ops/zkp-mvp/gpu-metal/zkp-core/Cargo.toml
O=$W/results/zk60_effplan_20261105/a14
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
P=$O/s2.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
/opt/homebrew/bin/cargo test --release --offline --locked --manifest-path $Z --lib -- --nocapture > $O/s2_zkpcore.log 2>&1; say "zkp-core lib tests rc=$?"
grep -E "^test result|A14-|panicked|^error" $O/s2_zkpcore.log | cut -c1-240 >> $P
/opt/homebrew/bin/cargo check --tests --offline --locked --manifest-path $H > $O/s2_check_nometal.log 2>&1; say "no-feature cargo check --tests rc=$?"
grep -E "^error" -A 8 $O/s2_check_nometal.log | head -60 >> $P
$C --no-run > $O/s2_build.log 2>&1
rc=$?
say "build rc=$rc"
if [ $rc -ne 0 ]; then
  grep -E "^error" -A 14 $O/s2_build.log | head -120 >> $P
  say "all done (build failed)"
  exit 1
fi
$C private_block::range16_tests::a14_the_lazy_sums_equal_the_per_term_sums_word_for_word -- --exact --nocapture --test-threads=1 > $O/s2_lazy.log 2>&1; say "a14 lazy sums word for word (CPU, rung) rc=$?"
grep -E "A14-|test result|panicked" $O/s2_lazy.log | cut -c1-260 >> $P
$C private_block::range16_tests::a14_the_8b_private_slots_tables_equal_under_both_sums -- --ignored --exact --nocapture --test-threads=1 > $O/s2_lazy8b.log 2>&1; say "a14 lazy sums word for word (8B private slots) rc=$?"
grep -E "A14-|test result|panicked" $O/s2_lazy8b.log | cut -c1-260 >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::a14_w16r2_rung_golden_under_every_a14_setting -- --ignored --exact --nocapture --test-threads=1 > $O/s2_rung.log 2>&1; say "a14 rung golden under every setting rc=$?"
grep -E "A14-|test result|panicked" $O/s2_rung.log | cut -c1-260 >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 HL_PB_ORACLE=0 $C private_block::w16r2_tests::a14_the_8b_block_proves_the_same_under_every_a14_setting -- --ignored --exact --nocapture --test-threads=1 > $O/s2_8b.log 2>&1; say "a14 8B block under every setting rc=$?"
grep -E "A14-|test result|panicked" $O/s2_8b.log | cut -c1-260 >> $P
say "all done"
