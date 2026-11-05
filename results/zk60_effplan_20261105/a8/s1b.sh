#!/bin/bash
# A8 stage 1b, THE SWEEP (diagnostic): stage 1 found the A8 fold bound by memory latency at each row's
# start (narrow chunks 2x slower), not by its accumulators. This build adds a software prefetch of the
# rows ahead and explicit NEON for the small-word lanes. Build; the word-for-word fold test (now also
# every prefetch distance and the NEON lanes); then on one W16R2 8B T128 block the store folds captured
# and every form timed: chunk width 128-1024, prefetch 0-2 rows ahead, NEON on and off; alone in pools of
# 6 and 32 threads, and six at once, each in its own pool of six. One guarded job, class gpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a6902a0faf57242d4
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$W/results/zk60_effplan_20261105/a8
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
T=private_block::w16r2_tests
P=$O/s1b.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$C --no-run > $O/s1b_build.log 2>&1
rc=$?
say "build rc=$rc"
if [ $rc -ne 0 ]; then
  grep -E "^error" -A 12 $O/s1b_build.log | head -80 >> $P
  say "all done (build failed)"
  exit 1
fi
$C $T::a8_store_fold_forms_equal_the_per_term_fold_word_for_word -- --exact --nocapture --test-threads=1 > $O/s1b_equal.log 2>&1; say "word-for-word fold test rc=$?"
grep -E "A8-FOLD-EQUAL|test result|panicked" $O/s1b_equal.log | cut -c1-300 >> $P
env HL_PB_ORACLE=0 HL_METAL_TIMING=0 $C $T::a8_store_fold_census_and_bench_on_the_8b_block -- --ignored --exact --nocapture --test-threads=1 > $O/s1b_bench.log 2>&1; say "census and bench rc=$?"
grep -E "A8-CENSUS|test result|panicked" $O/s1b_bench.log | cut -c1-420 >> $P
say "all done"
