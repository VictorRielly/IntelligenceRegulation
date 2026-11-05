#!/bin/bash
# A17 stage 3, THE A/Bs: in-process at N = 6, the arm order reversed in every odd pass (HL_D55_AB_ALTERNATE=1).
#  (1) the singles, proof only, 8 passes, five arms in one process: a17old, a17old+looked1, a17old+checked1,
#      a17old+reuse1, a17new (A14 stage 3's shape);
#  (2) a17old against a17new, 6 passes, each arm and pass a proof-only fork call, one request from its input (sealed)
#      and a 4-request stream (every stream receipt verified after its clock; each arm's first proof-only and sealed
#      receipt verified), the env of a15/s3.sh.
# One guarded job, class gpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a712d6f342b57b528
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$W/results/zk60_effplan_20261105/a17
PAIRS=$W/results/zk60_effplan_20261105/a11/pairs.py
SEAL13=$W/results/zk60_effplan_20261105/a13/seal_pairs.py
SEAL15=$W/results/zk60_effplan_20261105/a15/seal_pairs.py
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
D=private_block::run::fork::tests::d55_ab_one_request_serial_against_forks
P=$O/s3.progress
E0="HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=1 HL_D55_AB_ALTERNATE=1"
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
mkdir -p $O/raw
$C --no-run > $O/raw/s3_build.log 2>&1
rc=$?
say "build rc=$rc"
if [ $rc -ne 0 ]; then
  grep -E "^error" -A 14 $O/raw/s3_build.log | head -80 >> $P
  say "all done (build failed)"
  exit 1
fi
# (1) the singles, proof only
ARMS="a17old,a17old+looked1,a17old+checked1,a17old+reuse1,a17new"
env $E0 HL_D55_AB_PASSES=8 HL_D55_GPU_AB=$ARMS $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/raw/s3_singles_d55_ab.log 2>&1
say "d55 singles ($ARMS) rc=$?"
grep -E "^D55-AB SUMMARY|panicked" $O/raw/s3_singles_d55_ab.log | cut -c1-240 >> $P
for t in a17old+looked1 a17old+checked1 a17old+reuse1 a17new; do
  python3 $PAIRS $O/raw/s3_singles_d55_ab.log a17old $t --alternate --n 6 > $O/s3_pairs_singles_$t.md 2>&1
  cat $O/s3_pairs_singles_$t.md >> $P
done
# (2) the whole: proof only, one request, the stream
ab() {
  local tag=$1 base=$2 test=$3
  env $E0 HL_D55_AB_PASSES=6 HL_D55_AB_SEALED=1 HL_D55_AB_PIPE=4 HL_D55_GPU_AB=$base,$test $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/raw/s3_${tag}_d55_ab.log 2>&1
  say "d55 A/B $tag: $base against $test rc=$?"
  grep -E "^D55-AB SUMMARY|panicked" $O/raw/s3_${tag}_d55_ab.log | cut -c1-240 >> $P
  python3 $PAIRS $O/raw/s3_${tag}_d55_ab.log $base $test --alternate --n 6 > $O/s3_pairs_$tag.md 2>&1
  python3 $SEAL13 $O/raw/s3_${tag}_d55_ab.log $base $test --n 6 > $O/s3_seal13_$tag.md 2>&1
  python3 $SEAL15 $O/raw/s3_${tag}_d55_ab.log $base $test --n 6 > $O/s3_seal_$tag.md 2>&1
  cat $O/s3_pairs_$tag.md $O/s3_seal13_$tag.md $O/s3_seal_$tag.md >> $P
}
ab whole a17old a17new
say "all done"
