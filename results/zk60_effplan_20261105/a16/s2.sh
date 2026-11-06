#!/bin/bash
# A16 stage 2, THE A/Bs (in-process, N = 6, the arm order reversed in every odd pass; each arm and
# pass a proof-only fork call (the control), one request from its input (sealed) and a 4-request
# stream, every stream receipt verified after its clock, each arm's first proof-only and sealed
# receipt verified). The env of a15/s3.sh.
#  (1) 6 passes: the builder before A16 (spauto+a16old) against A16's default (spauto+a16def),
#      both in the default sealing pool (8 threads here);
#  (2) 4 passes, exploratory, the pool re-sweep on A16's default: 8 (spauto) against 12 and 16.
# Analysed with ../a11/pairs.py --alternate --n 6, ../a13/seal_pairs.py and ../a15/seal_pairs.py.
# One guarded job, class gpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a25af4fbe05476b8b
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$W/results/zk60_effplan_20261105/a16
PAIRS=$W/results/zk60_effplan_20261105/a11/pairs.py
SEAL13=$W/results/zk60_effplan_20261105/a13/seal_pairs.py
SEAL15=$W/results/zk60_effplan_20261105/a15/seal_pairs.py
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
D=private_block::run::fork::tests::d55_ab_one_request_serial_against_forks
P=$O/s2.progress
E="HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=1 HL_D55_AB_ALTERNATE=1 HL_D55_AB_SEALED=1 HL_D55_AB_PIPE=4"
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
mkdir -p $O/raw
$C --no-run > $O/raw/s2_build.log 2>&1
rc=$?
say "build rc=$rc"
if [ $rc -ne 0 ]; then
  grep -E "^error" -A 14 $O/raw/s2_build.log | head -80 >> $P
  say "all done (build failed)"
  exit 1
fi
ab() {
  local tag=$1 passes=$2 base=$3
  shift 3
  local arms=$base
  for t in "$@"; do arms="$arms,$t"; done
  env $E HL_D55_AB_PASSES=$passes HL_D55_GPU_AB=$arms $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/raw/s2_${tag}_d55_ab.log 2>&1
  say "d55 A/B $tag ($passes passes): $arms rc=$?"
  grep -E "^D55-AB SUMMARY|panicked|receipt [0-9]+ B" $O/raw/s2_${tag}_d55_ab.log | cut -c1-240 | sort | uniq -c | sort -rn | head -12 >> $P
  for t in "$@"; do
    local s=${t//+/_}
    python3 $PAIRS $O/raw/s2_${tag}_d55_ab.log $base $t --alternate --n 6 > $O/s2_pairs_${tag}_$s.md 2>&1
    python3 $SEAL13 $O/raw/s2_${tag}_d55_ab.log $base $t --n 6 > $O/s2_seal13_${tag}_$s.md 2>&1
    python3 $SEAL15 $O/raw/s2_${tag}_d55_ab.log $base $t --n 6 > $O/s2_seal_${tag}_$s.md 2>&1
    cat $O/s2_pairs_${tag}_$s.md $O/s2_seal13_${tag}_$s.md $O/s2_seal_${tag}_$s.md >> $P
  done
}
ab default 6 spauto+a16old spauto+a16def
ab pools 4 spauto+a16def sp12+a16def sp16+a16def
say "all done"
