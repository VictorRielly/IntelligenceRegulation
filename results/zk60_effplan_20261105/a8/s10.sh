#!/bin/bash
# A8 stage 10, THE A/B ON THE MERGED TREE (A8 + A12, whose device slots' tables moved the largest host region to
# the GPU): the stage 9 build reused; in-process at N = 6, 6 passes, the arm order reversed in every odd pass,
# the store fold before A8 (`m11`) against A8's (`small`, the default); each arm and pass: a proof-only fork call,
# one request from its input (sealed) and a stream of 4 requests (every stream receipt verified after its clock;
# the first proof-only and sealed call of each arm verified). One guarded job, class gpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a6902a0faf57242d4
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$W/results/zk60_effplan_20261105/a8
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
D=private_block::run::fork::tests::d55_ab_one_request_serial_against_forks
P=$O/s10.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$C --no-run > $O/s10_build.log 2>&1
rc=$?
say "build rc=$rc"
if [ $rc -ne 0 ]; then
  say "all done (build failed)"
  exit 1
fi
env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=1 HL_D55_AB_PASSES=6 HL_D55_AB_ALTERNATE=1 HL_D55_AB_SEALED=1 HL_D55_AB_PIPE=4 HL_D55_GPU_AB=m11,small $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/s10_d55_ab.log 2>&1
say "d55 A/B on the merged tree rc=$?"
grep -E "^D55-AB SUMMARY" $O/s10_d55_ab.log | cut -c1-220 >> $P
python3 $W/results/zk60_effplan_20261105/a11/pairs.py $O/s10_d55_ab.log m11 small --alternate --n 6 > $O/s10_pairs.md 2>&1
cat $O/s10_pairs.md >> $P
say "all done"
