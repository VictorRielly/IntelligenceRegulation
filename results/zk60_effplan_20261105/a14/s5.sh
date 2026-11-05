#!/bin/bash
# A14 stage 5, THE A/Bs OF THE DEFAULT (after stage 3: the lazy sums paid in every pair, the parallel absorb did not,
# the lane XOF was within noise), in-process at N = 6, the arm order reversed in every odd pass. (1) The lane XOF on
# top of the lazy sums, proof only, 8 passes: `a14old+lazy1` against `a14old+lazy1+xof8`. (2) The tree before A14
# (`a14old`) against the A14 default (`a14def` = xof8 + trser + lazy1), 6 passes, each arm and pass a proof-only fork
# call, one request from its input (sealed) and a stream of 4 requests (every stream receipt verified after its
# clock; the first proof-only and sealed call of each arm verified). One guarded job, class gpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a9838ab349101784d
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$W/results/zk60_effplan_20261105/a14
PAIRS=$W/results/zk60_effplan_20261105/a11/pairs.py
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
D=private_block::run::fork::tests::d55_ab_one_request_serial_against_forks
P=$O/s5.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$C --no-run > $O/s5_build.log 2>&1
rc=$?
say "build rc=$rc"
if [ $rc -ne 0 ]; then
  grep -E "^error" -A 14 $O/s5_build.log | head -80 >> $P
  say "all done (build failed)"
  exit 1
fi
env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=1 HL_D55_AB_PASSES=8 HL_D55_AB_ALTERNATE=1 HL_D55_GPU_AB=a14old+lazy1,a14old+lazy1+xof8 $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/raw/s5_xof_d55_ab.log 2>&1
say "d55 A/B, the lane XOF on top of the lazy sums, proof only rc=$?"
grep -E "^D55-AB SUMMARY" $O/raw/s5_xof_d55_ab.log | cut -c1-220 >> $P
python3 $PAIRS $O/raw/s5_xof_d55_ab.log a14old+lazy1 a14old+lazy1+xof8 --alternate --n 6 > $O/s5_pairs_xof_given_lazy.md 2>&1
cat $O/s5_pairs_xof_given_lazy.md >> $P
env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=1 HL_D55_AB_PASSES=6 HL_D55_AB_ALTERNATE=1 HL_D55_AB_SEALED=1 HL_D55_AB_PIPE=4 HL_D55_GPU_AB=a14old,a14def $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/raw/s5_d55_ab.log 2>&1
say "d55 A/B a14old against a14def, sealed + stream rc=$?"
grep -E "^D55-AB SUMMARY|verified" $O/raw/s5_d55_ab.log | cut -c1-220 >> $P
python3 $PAIRS $O/raw/s5_d55_ab.log a14old a14def --alternate --n 6 > $O/s5_pairs.md 2>&1
cat $O/s5_pairs.md >> $P
say "all done"
