#!/bin/bash
# A11 stage 3: build; the per-fork pool byte tests (the seeded W16R2 rung inside rayon pools of 1, 2, 3 and 6
# threads and in every host-matrix mode, CPU and Metal: every digest the golden 96e4f0b6); then an exploratory
# in-process A/B at N = 6 of the fork workers' rayon pools: `global` (the one global pool, the default) against
# each fork worker's own pool of 6, 12 and 24 threads, 6 passes, the arm order reversed in every odd pass.
# One guarded job, class gpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-ae8b54c76e79d7cfe
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$W/results/zk60_effplan_20261105/a11
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
$C private_block::w16r2_tests::a11_w16r2_rung_golden_inside_small_rayon_pools_and_in_every_host_matrix_mode -- --exact --nocapture --test-threads=1 > $O/s3_pools_cpu.log 2>&1; say "a11 CPU pool byte test rc=$?"
grep -E "A11-POOLS|test result" $O/s3_pools_cpu.log >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::a11_w16r2_rung_digests_in_per_fork_pools_on_the_device -- --ignored --exact --nocapture --test-threads=1 > $O/s3_pools_metal.log 2>&1; say "a11 Metal pool byte test rc=$?"
grep -E "A11-POOLS|test result" $O/s3_pools_metal.log | cut -c1-240 >> $P
env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=1 HL_D55_AB_PASSES=6 HL_D55_AB_ALTERNATE=1 HL_D55_GPU_AB=global,fp6,fp12,fp24 $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/s3_d55_ab.log 2>&1
say "d55 fork-pool A/B rc=$?"
grep -E "^D55-AB A11 USAGE|^D55-AB GPU-AB|^D55-AB SUMMARY" $O/s3_d55_ab.log | cut -c1-330 >> $P
for t in fp6 fp12 fp24; do
  python3 $O/pairs.py $O/s3_d55_ab.log global $t --alternate --n 6 > $O/s3_pairs_$t.md 2>&1
  cat $O/s3_pairs_$t.md >> $P
done
say "all done"
