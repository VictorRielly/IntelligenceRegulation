#!/bin/bash
# PRIVACY GATE lane, gate round 18 (second set, REVIEW_R14 §10 item 4 / coordinator 02:5x): the n sweep,
# n = 1, 11, 22 at L2 x v0 / v1 / vtie; the classifier rung captures through the
# FROZEN r14 test hooks (classify_capture_tests::capture_a_classify_rung_run),
# built in the gate's byte-equal copy of token frozen-r14
# (ops/zkp-mvp/gate-tinyllama/capture-tree-r14: 258 / 258 files = manifest_final_r14,
# list 0b4c429b...). Declarations: the token lane's rung captures peaked
# 0.20-0.22 GiB (tio-r12-cap-*), so need 0.7 / cap 1.5. A WINDOW_HOLD / lane
# HOLD check before each launch. Marker: r18_captures_n.done = 0 when all
# captures exited 0, else the first failing name.
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017
P=$E/round18/cap
H=/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/capture-tree-r14/hashline
C=/home/victor/zk60-artifacts/token-io/captures
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
W=/home/victor/IntelligenceRegulation/results/zk60_guard_fix_20261021/WINDOW_HOLD
FX=/tmp/claude-1000/-home-victor-IntelligenceRegulation/fd35cd14-b711-4cce-8e3f-39cf044eb009/scratchpad/fx18
CARGO=/home/victor/.cargo/bin/cargo
first_fail=""
cap() {  # cap <name> <L> <verdict> <chunk>
  local nm=$1 l=$2 v=$3 ch=$4 rc
  while [ -e $W ] || [ -e $E/HOLD ]; do sleep 30; done
  mkdir -p $FX
  python3 $G run --class cpu --need-gib 0.7 --cap-gib 1.5 --label gate18-cap-$nm --wait-secs 7200 --max-secs 900 \
    --log $P/cap-$nm.log --done $P/cap-$nm.guard.done --result-json $P/cap-$nm.guard.json -- \
    /usr/bin/env TMPDIR=$FX HL_TIO_FIXTURE_DIR=$FX HL_PB_CAPTURE_DIR=$C/$nm HL_PB_CAPTURE_BLOCKS=$l \
    HL_PB_CLASSIFY_VERDICT=$v HL_PB_CLASSIFY_CHUNK=$ch HL_RUN_CAPTURE_PUBLIC_TABLES=1 \
    HL_TEST_SOURCE_COMMIT=token-frozen-r14-0b4c429b-gate-copy \
    $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- \
    private_block::token_io::classify_capture_tests::capture_a_classify_rung_run --exact --ignored --nocapture
  rc=$?
  echo "$(date -u +%H:%M:%S) $nm exit $rc" >> $P/r18_captures_n.progress
  [ $rc -eq 0 ] || [ -n "$first_fail" ] || first_fail=$nm
}
cap classify-rc3-rung-L2-v0-short1 2 0 0/1
cap classify-rc3-rung-L2-v1-short1 2 1 0/1
cap classify-rc3-rung-L2-vtie-short1 2 tie 0/1
cap classify-rc3-rung-L2-v0-short11 2 0 0/11
cap classify-rc3-rung-L2-v1-short11 2 1 0/11
cap classify-rc3-rung-L2-vtie-short11 2 tie 0/11
cap classify-rc3-rung-L2-v0-short22 2 0 0/22
cap classify-rc3-rung-L2-v1-short22 2 1 0/22
cap classify-rc3-rung-L2-vtie-short22 2 tie 0/22
echo "${first_fail:-0}" > $P/r18_captures_n.done
