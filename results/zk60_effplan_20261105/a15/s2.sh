#!/bin/bash
# A15 stage 2, THE SIZE SWEEP (exploratory, to choose the default): the tree is perf ae58cae2+ (A14 merged, the XOF
# default blake3) with A15's sealing pool. In-process at N = 6, 4 passes, the whole arm order reversed in odd passes:
# sp0 (the global pool from the harness thread: the harness before A15), spg (the global pool entered on a worker:
# production's seal_and_record before A15), and sealing pools of 4, 6, 8, 12 and 16 threads. Each arm and pass: a
# proof-only fork call (a control: no sealing pass), one request from its input (sealed) and a 4-request stream
# (every stream receipt verified after its clock; each arm's first proof-only and sealed receipt verified). One
# guarded job, class gpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a87fcd65642aceb6b
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$W/results/zk60_effplan_20261105/a15
PAIRS=$W/results/zk60_effplan_20261105/a11/pairs.py
SEAL13=$W/results/zk60_effplan_20261105/a13/seal_pairs.py
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
D=private_block::run::fork::tests::d55_ab_one_request_serial_against_forks
P=$O/s2.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$C --no-run > $O/s2_build.log 2>&1
rc=$?
say "build rc=$rc"
if [ $rc -ne 0 ]; then
  grep -E "^error" -A 14 $O/s2_build.log | head -80 >> $P
  say "all done (build failed)"
  exit 1
fi
env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=1 HL_D55_AB_PASSES=4 HL_D55_AB_ALTERNATE=1 HL_D55_AB_SEALED=1 HL_D55_AB_PIPE=4 HL_D55_GPU_AB=sp0,spg,sp4,sp6,sp8,sp12,sp16 $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/raw/s2_d55_ab.log 2>&1
say "d55 size sweep rc=$?"
grep -E "^D55-AB SUMMARY|panicked|verified" $O/raw/s2_d55_ab.log | cut -c1-240 >> $P
for t in spg sp4 sp6 sp8 sp12 sp16; do
  python3 $PAIRS $O/raw/s2_d55_ab.log sp0 $t --alternate --n 6 > "$O/s2_pairs_$t.md" 2>&1
  python3 $SEAL13 $O/raw/s2_d55_ab.log sp0 $t --n 6 > "$O/s2_seal13_$t.md" 2>&1
  python3 $O/seal_pairs.py $O/raw/s2_d55_ab.log sp0 $t --n 6 > "$O/s2_seal_$t.md" 2>&1
  echo "--- $t against sp0" >> $P
  grep -E "^\| (proof wall|sealed|stream|user|sys)" "$O/s2_pairs_$t.md" >> $P
  grep -E "^\| (sealing pass|sealing CPU)" "$O/s2_seal13_$t.md" >> $P
done
for t in sp4 sp6 sp8 sp12 sp16; do
  python3 $PAIRS $O/raw/s2_d55_ab.log spg $t --alternate --n 6 > "$O/s2_pairs_spg_$t.md" 2>&1
  echo "--- $t against spg" >> $P
  grep -E "^\| (sealed|stream steady)" "$O/s2_pairs_spg_$t.md" >> $P
done
say "all done"
