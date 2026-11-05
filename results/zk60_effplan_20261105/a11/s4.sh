#!/bin/bash
# A11 stage 4: the per-fork pool's size, refined (no code change since stage 3): an in-process A/B at N = 6 of
# `global` against each fork worker's own pool of 4, 5, 6 and 8 threads, and of 6 threads with the host-matrix
# pool on (`fp6+pool`), 6 passes, the arm order reversed in every odd pass. One guarded job, class gpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-ae8b54c76e79d7cfe
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$W/results/zk60_effplan_20261105/a11
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
D=private_block::run::fork::tests::d55_ab_one_request_serial_against_forks
P=$O/s4.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$C --no-run > $O/s4_build.log 2>&1
rc=$?
say "build rc=$rc"
if [ $rc -ne 0 ]; then
  say "all done (build failed)"
  exit 1
fi
env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=1 HL_D55_AB_PASSES=6 HL_D55_AB_ALTERNATE=1 HL_D55_GPU_AB=global,fp4,fp5,fp6,fp8,fp6+pool $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/s4_d55_ab.log 2>&1
say "d55 fork-pool size A/B rc=$?"
grep -E "^D55-AB SUMMARY" $O/s4_d55_ab.log | cut -c1-200 >> $P
for t in fp4 fp5 fp6 fp8 fp6+pool; do
  python3 $O/pairs.py $O/s4_d55_ab.log global $t --alternate --n 6 > $O/s4_pairs_$t.md 2>&1
  cat $O/s4_pairs_$t.md >> $P
done
python3 $O/pairs.py $O/s4_d55_ab.log fp6 fp6+pool --alternate --n 6 > $O/s4_pairs_fp6_vs_fp6pool.md 2>&1
cat $O/s4_pairs_fp6_vs_fp6pool.md >> $P
say "all done"
