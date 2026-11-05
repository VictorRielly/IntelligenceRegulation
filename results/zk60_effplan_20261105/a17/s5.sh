#!/bin/bash
# A17 stage 5, THE A/Bs OF THE FINAL FORMS (after stage 3 dropped the kept matrices): build; the A17 suite tests;
# then in-process at N = 6, 6 passes, the arm order reversed in every odd pass, each arm and pass a proof-only fork
# call, one request from its input (sealed) and a 4-request stream (every stream receipt verified after its clock;
# each arm's first proof-only and sealed receipt verified), the env of a15/s3.sh:
#  (1) a17old (the code before A17) against a17new (the looked columns and the checked record: the default);
#  (2) looked1 against looked1+checked1 (the record's own effect on top of the views).
# One guarded job, class gpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a712d6f342b57b528
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$W/results/zk60_effplan_20261105/a17
F=/Users/victorrielly/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
PAIRS=$W/results/zk60_effplan_20261105/a11/pairs.py
SEAL13=$W/results/zk60_effplan_20261105/a13/seal_pairs.py
SEAL15=$W/results/zk60_effplan_20261105/a15/seal_pairs.py
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
D=private_block::run::fork::tests::d55_ab_one_request_serial_against_forks
P=$O/s5.progress
E0="HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=1 HL_D55_AB_ALTERNATE=1"
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
mkdir -p $O/raw
$C --no-run > $O/raw/s5_build.log 2>&1
rc=$?
say "build rc=$rc"
if [ $rc -ne 0 ]; then
  grep -E "^(error|warning: unused)" -A 14 $O/raw/s5_build.log | head -120 >> $P
  say "all done (build failed)"
  exit 1
fi
env HL_R13_LOADER_FIXTURES=$F $C a17_ -- --nocapture --test-threads=1 > $O/raw/s5_a17_suite.log 2>&1
say "a17 suite tests rc=$?"
grep -E "^A17|^test |test result|panicked" $O/raw/s5_a17_suite.log | cut -c1-260 >> $P
ab() {
  local tag=$1 base=$2 test=$3
  env $E0 HL_D55_AB_PASSES=6 HL_D55_AB_SEALED=1 HL_D55_AB_PIPE=4 HL_D55_GPU_AB=$base,$test $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/raw/s5_${tag}_d55_ab.log 2>&1
  say "d55 A/B $tag: $base against $test rc=$?"
  grep -E "^D55-AB SUMMARY|panicked" $O/raw/s5_${tag}_d55_ab.log | cut -c1-240 >> $P
  python3 $PAIRS $O/raw/s5_${tag}_d55_ab.log $base $test --alternate --n 6 > $O/s5_pairs_$tag.md 2>&1
  python3 $SEAL13 $O/raw/s5_${tag}_d55_ab.log $base $test --n 6 > $O/s5_seal13_$tag.md 2>&1
  python3 $SEAL15 $O/raw/s5_${tag}_d55_ab.log $base $test --n 6 > $O/s5_seal_$tag.md 2>&1
  cat $O/s5_pairs_$tag.md $O/s5_seal13_$tag.md $O/s5_seal_$tag.md >> $P
}
ab default a17old a17new
ab checked looked1 looked1+checked1
say "all done"
