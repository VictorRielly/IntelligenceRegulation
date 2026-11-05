#!/bin/bash
# A12 stage 3, THE A/B: the in-process A/B at N = 6 of `hosttab` (a device slot's tables built on the host, the
# path before A12) against `devtab` (built on the device ahead of the slot's first round, A's and H's rows read
# from the commitments' resident copies), 6 passes, the arm order reversed in every odd pass; each arm and pass:
# a proof-only fork call, one request from its input (sealed) and a stream of 4 requests (every stream receipt
# verified after its clock; the first proof-only and sealed call of each arm verified). Same build as stage 2
# (no source change). One guarded job, class gpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a79e5d1184b3df41f
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$W/results/zk60_effplan_20261105/a12
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
env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=1 HL_D55_AB_PASSES=6 HL_D55_AB_ALTERNATE=1 HL_D55_AB_SEALED=1 HL_D55_AB_PIPE=4 HL_D55_GPU_AB=hosttab,devtab $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/s3_d55_ab.log 2>&1
say "d55 A/B rc=$?"
grep -E "^D55-AB SUMMARY|panicked" $O/s3_d55_ab.log | cut -c1-240 >> $P
python3 $W/results/zk60_effplan_20261105/a11/pairs.py $O/s3_d55_ab.log hosttab devtab --alternate --n 6 > $O/s3_pairs.md 2>&1
cat $O/s3_pairs.md >> $P
python3 $O/summarize.py $O/s3_d55_ab.log > $O/s3_summary.md 2>&1
tail -6 $O/s3_summary.md >> $P
say "all done"
