#!/bin/bash
# A8 stage 1, THE CENSUS AND THE BENCH (diagnostic): build; the word-for-word fold test (random rows,
# every form and chunk width, the small path's overflow edge); the W16R2 rung golden under every store
# fold form on the device, every captured fold compared word for word; one W16R2 8B T128 block on the
# device under each form (digests equal), its two store folds captured, their census, and every form
# timed in pools of 6 and 32 threads; zkp-core's pcs tests. One guarded job, class gpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a6902a0faf57242d4
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
Z=$W/ops/zkp-mvp/gpu-metal/zkp-core/Cargo.toml
O=$W/results/zk60_effplan_20261105/a8
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
T=private_block::w16r2_tests
P=$O/s1.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$C --no-run > $O/s1_build.log 2>&1
rc=$?
say "build rc=$rc"
if [ $rc -ne 0 ]; then
  grep -E "^error|^warning: unused" -A 6 $O/s1_build.log | head -80 >> $P
  say "all done (build failed)"
  exit 1
fi
$C $T::a8_store_fold_forms_equal_the_per_term_fold_word_for_word -- --exact --nocapture --test-threads=1 > $O/s1_equal.log 2>&1; say "word-for-word fold test rc=$?"
grep -E "A8-FOLD-EQUAL|test result|panicked" $O/s1_equal.log | cut -c1-300 >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C $T::a8_w16r2_rung_golden_under_every_store_fold_form -- --ignored --exact --nocapture --test-threads=1 > $O/s1_rung.log 2>&1; say "rung golden under every form rc=$?"
grep -E "A8-RUNG|test result|panicked" $O/s1_rung.log | cut -c1-300 >> $P
env HL_PB_ORACLE=0 HL_METAL_TIMING=1 $C $T::a8_store_fold_census_and_bench_on_the_8b_block -- --ignored --exact --nocapture --test-threads=1 > $O/s1_bench.log 2>&1; say "census and bench rc=$?"
grep -E "A8-CENSUS|A8-BENCH|test result|panicked" $O/s1_bench.log | cut -c1-420 >> $P
/opt/homebrew/bin/cargo test --release --offline --locked --manifest-path $Z --lib pcs > $O/s1_zkpcore_pcs.log 2>&1; say "zkp-core pcs tests rc=$?"
grep -E "test result" $O/s1_zkpcore_pcs.log >> $P
say "all done"
