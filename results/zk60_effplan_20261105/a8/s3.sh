#!/bin/bash
# A8 stage 3, THE ATTRIBUTION (proof-only calls, the phase clock in every fork): the tree before A8
# (`m11+cols+vecfill`), each A8 part alone (the store fold `small`, the column weights `nocols`, the zeroed
# allocation `calloc`), and all of A8 together, N = 6, 6 passes, the whole arm order reversed in every odd
# pass. One guarded job, class gpu (the stage 2 build is reused).
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a6902a0faf57242d4
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$W/results/zk60_effplan_20261105/a8
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
D=private_block::run::fork::tests::d55_ab_one_request_serial_against_forks
BASE=m11+cols+vecfill+phases
ARMS=$BASE,small+cols+vecfill+phases,m11+nocols+vecfill+phases,m11+cols+calloc+phases,small+nocols+calloc+phases
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
env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=1 HL_D55_AB_PASSES=6 HL_D55_AB_ALTERNATE=1 HL_D55_GPU_AB=$ARMS $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/s3_d55_ab.log 2>&1
say "d55 attribution A/B rc=$?"
grep -E "^D55-AB SUMMARY" $O/s3_d55_ab.log | cut -c1-220 >> $P
for t in small+cols+vecfill+phases m11+nocols+vecfill+phases m11+cols+calloc+phases small+nocols+calloc+phases; do
  python3 $W/results/zk60_effplan_20261105/a11/pairs.py $O/s3_d55_ab.log $BASE $t --alternate --n 6 > $O/s3_pairs_$t.md 2>&1
  cat $O/s3_pairs_$t.md >> $P
done
say "all done"
