#!/bin/bash
# gate round 19: ONE R13-rung capture (L2 v1) to verify the fixed hook before the queue (coordinator, ~11:25Z)
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017
P=$E/round19/cap/one
H=/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/capture-tree-r16b/hashline
C=/home/victor/zk60-artifacts/token-io/captures
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
W=/home/victor/IntelligenceRegulation/results/zk60_guard_fix_20261021/WINDOW_HOLD
FX=/tmp/claude-1000/-home-victor-IntelligenceRegulation/fd35cd14-b711-4cce-8e3f-39cf044eb009/scratchpad/fx19
R13FX=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
CARGO=/home/victor/.cargo/bin/cargo
mkdir -p $P $FX
while [ -e $W ] || [ -e $E/HOLD ]; do sleep 30; done
python3 $G run --class build --need-gib 2.7 --cap-gib 3.5 --label gate19-build-tests-2 --wait-secs 14400 --max-secs 2400 \
  --log $P/build.log --done $P/build.guard.done --result-json $P/build.guard.json -- \
  /usr/bin/env TMPDIR=$FX HL_TIO_FIXTURE_DIR=$FX $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib --no-run
rc=$?; [ $rc -eq 0 ] || { echo build > $P/one.done; exit 0; }
nm=classify-r13-rung-L2-v1
python3 $G run --class cpu --need-gib 1.2 --cap-gib 2.5 --label gate19-cap-one --wait-secs 14400 --max-secs 1200 \
  --log $P/cap.log --done $P/cap.guard.done --result-json $P/cap.guard.json -- \
  /usr/bin/env TMPDIR=$FX HL_TIO_FIXTURE_DIR=$FX HL_R13_LOADER_FIXTURES=$R13FX HL_PB_CAPTURE_DIR=$C/$nm HL_PB_CAPTURE_BLOCKS=2 \
  HL_PB_CLASSIFY_VERDICT=1 HL_PB_CLASSIFY_CHUNK=whole HL_RUN_CAPTURE_PUBLIC_TABLES=1 HL_TEST_SOURCE_COMMIT=token-frozen-r16b-04d94bc0-gate-copy+H19 \
  $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- \
  private_block::token_io::classify_capture_tests::gate19::gate19_capture_an_r13_rung_classify_run --exact --ignored --nocapture
echo $? > $P/one.done
