#!/bin/bash
# A15 stage 3, THE A/Bs OF THE DEFAULT (after stage 2's sweep chose the rule): in-process at N = 6, 6 passes, the
# arm order reversed in every odd pass; each arm and pass a proof-only fork call (the control), one request from its
# input (sealed) and a 4-request stream (every stream receipt verified after its clock; each arm's first proof-only
# and sealed receipt verified).
#  (1) sp0 (the global pool from the harness thread: the harness before A15) against spauto (the A15 default);
#  (2) the coordinator's check of A14's lazy sums on top of the sealing pool: spauto (lazy1, the default) against
#      spauto+lazy0 (A14's per-term sums).
# (spg, production's form before A15, against the pools: stage 2's sweep, 4 passes.)
# One guarded job, class gpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a87fcd65642aceb6b
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$W/results/zk60_effplan_20261105/a15
PAIRS=$W/results/zk60_effplan_20261105/a11/pairs.py
SEAL13=$W/results/zk60_effplan_20261105/a13/seal_pairs.py
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
D=private_block::run::fork::tests::d55_ab_one_request_serial_against_forks
P=$O/s3.progress
E="HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=1 HL_D55_AB_PASSES=6 HL_D55_AB_ALTERNATE=1 HL_D55_AB_SEALED=1 HL_D55_AB_PIPE=4"
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$C --no-run > $O/s3_build.log 2>&1
rc=$?
say "build rc=$rc"
if [ $rc -ne 0 ]; then
  grep -E "^error" -A 14 $O/s3_build.log | head -80 >> $P
  say "all done (build failed)"
  exit 1
fi
ab() {
  local tag=$1 base=$2 test=$3
  env $E HL_D55_GPU_AB=$base,$test $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/raw/s3_${tag}_d55_ab.log 2>&1
  say "d55 A/B $tag: $base against $test rc=$?"
  grep -E "^D55-AB SUMMARY|panicked" $O/raw/s3_${tag}_d55_ab.log | cut -c1-240 >> $P
  python3 $PAIRS $O/raw/s3_${tag}_d55_ab.log $base $test --alternate --n 6 > $O/s3_pairs_$tag.md 2>&1
  python3 $SEAL13 $O/raw/s3_${tag}_d55_ab.log $base $test --n 6 > $O/s3_seal13_$tag.md 2>&1
  python3 $O/seal_pairs.py $O/raw/s3_${tag}_d55_ab.log $base $test --n 6 > $O/s3_seal_$tag.md 2>&1
  cat $O/s3_pairs_$tag.md $O/s3_seal13_$tag.md $O/s3_seal_$tag.md >> $P
}
ab default sp0 spauto
ab lazy spauto spauto+lazy0
say "all done"
