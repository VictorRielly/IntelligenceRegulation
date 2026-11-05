#!/bin/bash
# A11 stage 2: build; the two equality tests (the host pool's zeroed buffers against `vec!`, and zkp-core's
# `from_u128` against the 128-bit division); then the in-process A/B at N = 6 of the A/H host matrices:
# `nopool` (the pre-A11 `vec!` on the fork thread) against `pool` (A11: reused, zeroed in parallel), 8 passes,
# the arm order alternating pass by pass (HL_D55_AB_ALTERNATE=1), the first pass of each arm verified.
# `from_u128` is in both arms. One guarded job, class gpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-ae8b54c76e79d7cfe
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
Z=$W/ops/zkp-mvp/gpu-metal/zkp-core/Cargo.toml
O=$W/results/zk60_effplan_20261105/a11
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
D=private_block::run::fork::tests::d55_ab_one_request_serial_against_forks
P=$O/s2.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$C --no-run > $O/s2_build.log 2>&1
rc=$?
say "build rc=$rc"
if [ $rc -ne 0 ]; then
  say "all done (build failed)"
  exit 1
fi
$C private_block::host_pool::tests -- --test-threads=1 > $O/s2_hostpool_test.log 2>&1; say "host pool equality test rc=$?"
grep -E "^test |test result" $O/s2_hostpool_test.log >> $P
/opt/homebrew/bin/cargo test --release --offline --locked --manifest-path $Z --lib field:: > $O/s2_zkpcore_field.log 2>&1; say "zkp-core field tests rc=$?"
grep -E "^test |test result" $O/s2_zkpcore_field.log >> $P
env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=1 HL_D55_AB_PASSES=8 HL_D55_AB_ALTERNATE=1 HL_D55_GPU_AB=shared+spin+nopool,shared+spin+pool $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/s2_d55_ab.log 2>&1
say "d55 pool A/B rc=$?"
grep -E "^D55-AB A11 USAGE|^D55-AB GPU-AB|^D55-AB SUMMARY" $O/s2_d55_ab.log | cut -c1-330 >> $P
python3 $O/pairs.py $O/s2_d55_ab.log shared+spin+nopool shared+spin+pool --alternate --n 6 > $O/s2_pairs.md 2>&1
say "pairs rc=$?"
cat $O/s2_pairs.md >> $P
say "all done"
