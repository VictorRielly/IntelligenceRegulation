#!/bin/bash
# A13 stage 3, MEMORY PER WINDOW: one process per window W (0, 4, 8, 16, 32), the Metal buffer pool OFF
# (HL_METAL_POOL=0, so a freed buffer goes back to the system and the footprint is what is live; the timings of
# this stage are NOT comparable and are not used), N = 6: one request from its input (the footprint at its start,
# its peak sampled every 10 ms, its end) and a 4-request stream (the same), every receipt verified. Same build as
# stage 2. One guarded job, class gpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-afed131c59aa694b5
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$W/results/zk60_effplan_20261105/a13
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
D=private_block::run::fork::tests::d55_ab_one_request_serial_against_forks
P=$O/s3.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$C --no-run > $O/s3_build.log 2>&1
rc=$?
say "build rc=$rc"
if [ $rc -ne 0 ]; then
  say "all done (build failed)"
  exit 1
fi
for A in 0 4 8 16 32; do
  env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_METAL_POOL=0 HL_D55_AHEAD=$A HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=1 HL_D55_SEALED=1 HL_D55_PIPE=4 $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/s3_mem_w$A.log 2>&1
  say "window $A rc=$?"
  grep -E "^D55-AB A13 (SEALED|PIPE-MEM|PIPE-SEAL)|verified|panicked" $O/s3_mem_w$A.log | cut -c1-420 >> $P
done
say "all done"
