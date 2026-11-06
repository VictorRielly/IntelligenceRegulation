#!/bin/bash
# A22 stage 1, on the tree with A21 merged (perf 2eb26c7f): the R13 export stream test on the CPU, then the byte
# evidence on the Metal device. The R13 export through the server (the stream with every
# refusal and failure, the bytes against stack-prove, fresh randomness, and A19's checks with seeded lanes at windows
# 0, 2 and L, digests ahead off and on); the resident synthetic W16R2 rung (windows 0, 2 and 4, lanes 1 and 2); the
# resident 8B synthetic stack (L = 4; digests ahead off and on). One guarded job, class gpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a75997b3d20d4ca57
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$W/results/zk60_effplan_20261105/a22
F=/Users/victorrielly/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
K=private_block::run::fork::tests::a22
P=$O/s1.progress
R=$O/raw
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$C --no-run > $R/s1_build.log 2>&1
rc=$?
say "build rc=$rc"
if [ $rc -ne 0 ]; then
  grep -E "^error" -A 14 $R/s1_build.log | head -120 >> $P
  say "all done (build failed)"
  exit 1
fi
# the R13 export stream test on the CPU again (stage 0 stopped it at a NaN in a result line; fixed), on the merged tree
env HL_R13_LOADER_FIXTURES=$F $C $K::a22_the_server_proves_the_r13_export_as_stack_prove_does_and_carries_on_after_every_refusal -- --exact --nocapture --test-threads=1 > $R/s1_export_cpu.log 2>&1; say "a22 R13 export stream on the CPU rc=$?"
grep -E "^A22-|test result|panicked" $R/s1_export_cpu.log | cut -c1-900 >> $P
for t in a22_the_server_proves_the_r13_export_as_stack_prove_does_and_carries_on_after_every_refusal_on_the_device a22_the_resident_synthetic_rung_stream_replays_with_the_window_off_and_on_on_the_device; do
  env HL_R13_LOADER_FIXTURES=$F HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C $K::$t -- --ignored --exact --nocapture --test-threads=1 > $R/s1_$t.log 2>&1; say "$t rc=$?"
  grep -E "^A22-|test result|panicked" $R/s1_$t.log | cut -c1-900 >> $P
done
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 HL_PB_ORACLE=0 $C $K::a22_the_resident_8b_stream_replays -- --ignored --exact --nocapture --test-threads=1 > $R/s1_8b.log 2>&1; say "a22_the_resident_8b_stream_replays rc=$?"
grep -E "^A22-|test result|panicked" $R/s1_8b.log | cut -c1-900 >> $P
say "all done"
