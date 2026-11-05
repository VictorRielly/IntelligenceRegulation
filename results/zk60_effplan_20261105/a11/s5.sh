#!/bin/bash
# A11 stage 5, THE CONFIRMATORY A/B of the new default: build (now with the per-fork pools as the default,
# ceil(32 / 6) = 6 threads per fork worker at N = 6); the size-rule unit test; then the in-process A/B at N = 6
# of `global` (the pre-A11 path) against `fpauto` (the default rule), 6 passes, the arm order reversed in every
# odd pass, each arm and pass: a proof-only fork call, one request from its input (sealed) and a stream of 4
# requests (every stream receipt verified after its clock; the first proof-only and sealed call of each arm
# verified). One guarded job, class gpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-ae8b54c76e79d7cfe
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$W/results/zk60_effplan_20261105/a11
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
D=private_block::run::fork::tests::d55_ab_one_request_serial_against_forks
P=$O/s5.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$C --no-run > $O/s5_build.log 2>&1
rc=$?
say "build rc=$rc"
if [ $rc -ne 0 ]; then
  say "all done (build failed)"
  exit 1
fi
$C private_block::run::fork::tests::a11_the_fork_pool_size_rule -- --exact --test-threads=1 > $O/s5_rule_test.log 2>&1; say "fork pool size rule test rc=$?"
grep -E "test result" $O/s5_rule_test.log >> $P
env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=1 HL_D55_AB_PASSES=6 HL_D55_AB_ALTERNATE=1 HL_D55_AB_SEALED=1 HL_D55_AB_PIPE=4 HL_D55_GPU_AB=global,fpauto $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/s5_d55_ab.log 2>&1
say "d55 default A/B rc=$?"
grep -E "^D55-AB SUMMARY" $O/s5_d55_ab.log | cut -c1-220 >> $P
python3 $O/pairs.py $O/s5_d55_ab.log global fpauto --alternate --n 6 > $O/s5_pairs.md 2>&1
cat $O/s5_pairs.md >> $P
say "all done"
