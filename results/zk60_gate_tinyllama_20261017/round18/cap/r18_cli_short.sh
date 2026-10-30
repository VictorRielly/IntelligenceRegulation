#!/bin/bash
# PRIVACY GATE lane, gate round 18: the P-18 CLI path for ONE SHORT item (REVIEW_R14 §10 item 4),
# through the token lane's NAMED r14 binary, recorded by the gate's test-only patch H18-1
# (classify_capture_tests.rs, not a source pin; patch round18/cap/H18-1.classify_capture_tests.patch).
# 1. rebuild the lib test binary in the gate's capture tree (build class: the round's first build
#    peaked 2.17 GiB -> need 2.7 / cap 3.5); 2. the capture at n = 11 (cpu, need 0.7 / cap 1.5).
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017
P=$E/round18/cap
H=/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/capture-tree-r14/hashline
C=/home/victor/zk60-artifacts/token-io/captures
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
W=/home/victor/IntelligenceRegulation/results/zk60_guard_fix_20261021/WINDOW_HOLD
FX=/tmp/claude-1000/-home-victor-IntelligenceRegulation/fd35cd14-b711-4cce-8e3f-39cf044eb009/scratchpad/fx18
CARGO=/home/victor/.cargo/bin/cargo
B=/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/cli/zk60_classify.r14.release.bin
BSHA=48dac98818f795a2a04b4b7f54e48d1a71f61fb09fbbd9de314101c9a661a986
echo "$BSHA  $B" | sha256sum -c > $P/cli-short-binary-check.txt 2>&1 || { echo binary > $P/r18_cli_short.done; exit 0; }
while [ -e $W ] || [ -e $E/HOLD ]; do sleep 30; done
python3 $G run --class build --need-gib 2.7 --cap-gib 3.5 --label gate18-build-tests-h18 --wait-secs 7200 --max-secs 2400 \
  --log $P/build-tests-h18.log --done $P/build-tests-h18.guard.done --result-json $P/build-tests-h18.guard.json -- \
  /usr/bin/env TMPDIR=$FX HL_TIO_FIXTURE_DIR=$FX $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib --no-run
rc=$?; [ $rc -eq 0 ] || { echo build > $P/r18_cli_short.done; exit 0; }
while [ -e $W ] || [ -e $E/HOLD ]; do sleep 30; done
mkdir -p $FX
NM=classify-rc3-cli-short11-r14
python3 $G run --class cpu --need-gib 0.7 --cap-gib 1.5 --label gate18-cap-$NM --wait-secs 7200 --max-secs 900 \
  --log $P/cap-$NM.log --done $P/cap-$NM.guard.done --result-json $P/cap-$NM.guard.json -- \
  /usr/bin/env TMPDIR=$FX HL_TIO_FIXTURE_DIR=$FX HL_PB_CAPTURE_DIR=$C/$NM HL_PB_CLI_BIN=$B HL_PB_CLI_BIN_SHA256=$BSHA \
  HL_RUN_CAPTURE_PUBLIC_TABLES=1 HL_PB_CLI_SHORT_N=11 HL_GATE18_STATEMENT_OUT=$P/$NM.statement.json \
  HL_TEST_SOURCE_COMMIT=token-frozen-r14-0b4c429b-gate-copy+H18-1 \
  $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- \
  private_block::token_io::classify_capture_tests::gate18_capture_a_short_item_through_the_cli --exact --ignored --nocapture
echo $? > $P/r18_cli_short.done
