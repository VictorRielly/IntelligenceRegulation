#!/bin/bash
# A13 stage 1, MEASURE FIRST (no production change; the harness only prints the sealing pass's CPU occupancy and,
# with HL_D55_TIMELINE=1, its GPU timeline): the before-challenge part's real time per block in a fork run at N = 1
# and N = 6 (the phase clock, `HL_D55_GPU_AB=phases`), and the sealing pass's CPU and GPU occupancy (the SEALED
# arm at N = 1 and N = 6). One guarded job, class gpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-afed131c59aa694b5
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$W/results/zk60_effplan_20261105/a13
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
D=private_block::run::fork::tests::d55_ab_one_request_serial_against_forks
P=$O/s1.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$C --no-run > $O/s1_build.log 2>&1
rc=$?
say "build rc=$rc"
if [ $rc -ne 0 ]; then
  say "all done (build failed)"
  exit 1
fi
env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=1,6 HL_D55_PASSES=1 HL_D55_SEALED=1 HL_D55_TIMELINE=1 HL_D55_AB_PASSES=1 HL_D55_GPU_AB=phases $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/s1_d55.log 2>&1
say "d55 measure rc=$?"
grep -E "^D55-AB A13 SEAL|sealing pass N|GPU busy|tag wprod|^D55-AB SUMMARY|panicked" $O/s1_d55.log | cut -c1-300 >> $P
grep -E "^D55-AB A11 PHASE N[16] \[phases\] \| (A:|M:|ALL)" $O/s1_d55.log | cut -c1-200 >> $P
say "all done"
