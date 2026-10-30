#!/bin/bash
# PRIVACY GATE lane, gate round 19: the R13-rung classifier captures through the gate's test-only
# hook H19-1 (gate19_capture_an_r13_rung_classify_run), built in the gate's copy of token frozen-r16b
# (ops/zkp-mvp/gate-tinyllama/capture-tree-r16b: 301 / 301 files = manifest_final_r16b, list 04d94bc0...,
# plus the H19 test-only patch: classify_capture_tests.rs one #[path] line, gate19_capture_tests.rs new).
# 1. build the lib test binary (build class; round 18's build peaked 2.17 GiB -> need 2.7 / cap 3.5);
# 2. the captures (cpu class; first measurement at the R13 rung: need 1.2 / cap 2.5).
# A WINDOW_HOLD / lane HOLD check before each launch. Marker r19_captures.done = 0 when all exited 0,
# else the first failing name ("build" when the build failed).
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017
P=$E/round19/cap
H=/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/capture-tree-r16b/hashline
C=/home/victor/zk60-artifacts/token-io/captures
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
W=/home/victor/IntelligenceRegulation/results/zk60_guard_fix_20261021/WINDOW_HOLD
FX=/tmp/claude-1000/-home-victor-IntelligenceRegulation/fd35cd14-b711-4cce-8e3f-39cf044eb009/scratchpad/fx19
R13FX=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
CARGO=/home/victor/.cargo/bin/cargo
COMMIT=token-frozen-r16b-04d94bc0-gate-copy+H19
first_fail=""
hold() { while [ -e $W ] || [ -e $E/HOLD ]; do sleep 30; done; }
mkdir -p $FX
hold
python3 $G run --class build --need-gib 2.7 --cap-gib 3.5 --label gate19-build-tests --wait-secs 14400 --max-secs 2400 \
  --log $P/build-tests.log --done $P/build-tests.guard.done --result-json $P/build-tests.guard.json -- \
  /usr/bin/env TMPDIR=$FX HL_TIO_FIXTURE_DIR=$FX $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib --no-run
rc=$?
echo "$(date -u +%H:%M:%S) build exit $rc" >> $P/r19_captures.progress
[ $rc -eq 0 ] || { echo build > $P/r19_captures.done; exit 0; }
cap() {  # cap <name> <L> <verdict> <chunk>
  local nm=$1 l=$2 v=$3 ch=$4 rc
  hold
  python3 $G run --class cpu --need-gib 1.2 --cap-gib 2.5 --label gate19-cap-$nm --wait-secs 14400 --max-secs 1200 \
    --log $P/cap-$nm.log --done $P/cap-$nm.guard.done --result-json $P/cap-$nm.guard.json -- \
    /usr/bin/env TMPDIR=$FX HL_TIO_FIXTURE_DIR=$FX HL_R13_LOADER_FIXTURES=$R13FX HL_PB_CAPTURE_DIR=$C/$nm HL_PB_CAPTURE_BLOCKS=$l \
    HL_PB_CLASSIFY_VERDICT=$v HL_PB_CLASSIFY_CHUNK=$ch HL_RUN_CAPTURE_PUBLIC_TABLES=1 HL_TEST_SOURCE_COMMIT=$COMMIT \
    $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- \
    private_block::token_io::classify_capture_tests::gate19::gate19_capture_an_r13_rung_classify_run --exact --ignored --nocapture
  rc=$?
  echo "$(date -u +%H:%M:%S) $nm exit $rc" >> $P/r19_captures.progress
  # attempt 2 (11:2x): stop at the first failure (attempt 1 ran 13 failing captures in 3 s)
  [ $rc -eq 0 ] || { echo "$nm" > $P/r19_captures.done; exit 0; }
}
# classify-r13-rung-L2-v1 was made and checked by r19_one.sh (attempt 5, 11:3xZ)
cap classify-r13-rung-L2-v0 2 0 whole
cap classify-r13-rung-L2-vtie 2 tie whole
cap classify-r13-rung-L1-v1 1 1 whole
cap classify-r13-rung-L2-v1-chunk0o27 2 1 0/27
cap classify-r13-rung-L2-v1-chunk1o27 2 1 1/27
cap classify-r13-rung-L2-v0-short1 2 0 0/1
cap classify-r13-rung-L2-v1-short1 2 1 0/1
cap classify-r13-rung-L2-vtie-short1 2 tie 0/1
cap classify-r13-rung-L2-v0-short11 2 0 0/11
cap classify-r13-rung-L2-v1-short11 2 1 0/11
cap classify-r13-rung-L2-vtie-short11 2 tie 0/11
cap classify-r13-rung-L2-v1-short22 2 1 0/22
echo "${first_fail:-0}" > $P/r19_captures.done
