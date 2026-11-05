#!/bin/bash
# A14 stage 3, THE A/Bs, in-process at N = 6, the arm order reversed in every odd pass. (1) Each A14 form alone on
# the tree before A14, proof only, 8 passes: `a14old` (all three old) against `a14old+xof8`, `a14old+trpar`,
# `a14old+lazy1` and `a14new` (all three new, the default). (2) `a14old` against `a14new`, 6 passes, each arm and
# pass a proof-only fork call, one request from its input (sealed) and a stream of 4 requests (every stream receipt
# verified after its clock; the first proof-only and sealed call of each arm verified). One guarded job, class gpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a9838ab349101784d
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$W/results/zk60_effplan_20261105/a14
PAIRS=$W/results/zk60_effplan_20261105/a11/pairs.py
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
env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=1 HL_D55_AB_PASSES=8 HL_D55_AB_ALTERNATE=1 HL_D55_GPU_AB=a14old,a14old+xof8,a14old+trpar,a14old+lazy1,a14new $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/raw/s3_singles_d55_ab.log 2>&1
say "d55 A/B, each form alone, proof only rc=$?"
grep -E "^D55-AB SUMMARY" $O/raw/s3_singles_d55_ab.log | cut -c1-220 >> $P
for t in a14old+xof8 a14old+trpar a14old+lazy1 a14new; do
  python3 $PAIRS $O/raw/s3_singles_d55_ab.log a14old $t --alternate --n 6 > "$O/s3_pairs_singles_$t.md" 2>&1
  cat "$O/s3_pairs_singles_$t.md" >> $P
done
env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=1 HL_D55_AB_PASSES=6 HL_D55_AB_ALTERNATE=1 HL_D55_AB_SEALED=1 HL_D55_AB_PIPE=4 HL_D55_GPU_AB=a14old,a14new $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/raw/s3_d55_ab.log 2>&1
say "d55 A/B a14old against a14new, sealed + stream rc=$?"
grep -E "^D55-AB SUMMARY|verified" $O/raw/s3_d55_ab.log | cut -c1-220 >> $P
python3 $PAIRS $O/raw/s3_d55_ab.log a14old a14new --alternate --n 6 > $O/s3_pairs.md 2>&1
cat $O/s3_pairs.md >> $P
say "all done"
