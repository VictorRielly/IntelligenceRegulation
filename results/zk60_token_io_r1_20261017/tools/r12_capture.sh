#!/bin/bash
# ROUND 12 classifier capture hooks (gate round 16 request §4): the test batch (the classifier
# capture tests plus the classifier, CLI, token-capture and run-capture tests, to show the shared
# recorder still writes block and token bundles as before), then the gate's rung captures:
# L = 1 and 2 at verdicts 0 / 1 / tie, plus one D41 chunk (L = 2, verdict 1, chunk 1 of 27).
# Every job: the pre-check outside the lock (r8_stack.sh's pre()), then the guard.
# Marker logs/r12_capture.done = 0 when all passed, else the failing step's name.
R=/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017
L=$R/logs
H=/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io/hashline
CARGO=/home/victor/.cargo/bin/cargo
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
C=/home/victor/zk60-artifacts/token-io/captures
finish() { echo "$1" > $L/r12_capture.done; exit 0; }
pre() {  # $1 = need
  until out=$(python3 $G check --class cpu --need-gib $1 2>&1); echo "$out" | grep -q "OK to start now" || ! echo "$out" | sed 's/[^;]*is held//g' | grep -q "budget\|MemAvailable"; do sleep 30; done
}
python3 $R/tools/manifest.py $R/manifest_r12D.sha256 $R/manifest_final_r12.sha256 > $L/r12D-manifest.log 2>&1
SRC="uncommitted token-io working copy = manifest_r12D (list sha256 $(sha256sum $R/manifest_r12D.sha256 | cut -c1-64))"
pre 4
python3 $G run --class cpu --need-gib 4 --cap-gib 6 --label tio-r12-t4-capture --wait-secs 14400 --max-secs 2700 \
  --log $L/r12-t4-capture.log --done $L/r12-t4-capture.guard.done --result-json $L/r12-t4-capture.guard.json \
  -- $CARGO test --release --offline --locked -j2 --no-fail-fast --manifest-path $H/Cargo.toml --lib -- \
  token_io::classify token_io::capture_tests run_capture_tests --test-threads 4 --nocapture
[ $? -eq 0 ] || finish t4
mkdir -p -m 0700 $C
for spec in "1 0 whole" "1 1 whole" "1 tie whole" "2 0 whole" "2 1 whole" "2 tie whole" "2 1 1/27"; do
  set -- $spec
  NAME=classify-rung-L$1-v$2
  [ "$3" = whole ] || NAME=$NAME-chunk$(echo $3 | tr / o)
  D=$C/$NAME
  [ -e $D ] && finish "exists-$NAME"
  pre 3
  python3 $G run --class cpu --need-gib 3 --cap-gib 6 --label tio-r12-cap-$NAME --wait-secs 14400 --max-secs 1800 \
    --log $L/r12-cap-$NAME.log --done $L/r12-cap-$NAME.guard.done --result-json $L/r12-cap-$NAME.guard.json \
    -- /usr/bin/env HL_PB_CAPTURE_DIR=$D HL_PB_CAPTURE_BLOCKS=$1 HL_PB_CLASSIFY_VERDICT=$2 HL_PB_CLASSIFY_CHUNK=$3 \
       HL_RUN_CAPTURE_PUBLIC_TABLES=1 "HL_TEST_SOURCE_COMMIT=$SRC" \
       $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- \
       private_block::token_io::classify_capture_tests::capture_a_classify_rung_run --exact --ignored --nocapture
  [ $? -eq 0 ] || finish "cap-$NAME"
done
finish 0
