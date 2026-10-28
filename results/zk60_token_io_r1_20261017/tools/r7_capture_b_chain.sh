#!/bin/bash
# Round 7, item 4 step B: the capture checker's linear decommitment scan (t31: the three capture tests),
# then the gate's whole-model TinyLlama captures (L = 22, dense and fixed) and the Llama-3-8B T32
# captures at reduced L (1 block, dense and fixed), all with the public tables' values, into
# $HOME/zk60-artifacts/token-io/captures/ (outside the repository).
R=/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017
L=$R/logs
H=/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io/hashline
C=/home/victor/zk60-artifacts/token-io/captures
G="python3 /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
python3 $R/tools/manifest.py $R/manifest_r7D.sha256 $R/manifest_r7C.sha256 > $L/r7d-manifest.log 2>&1
$G --class cpu --need-gib 4 --cap-gib 6 --label tio-t31-capture --wait-secs 14400 --max-secs 2700 --log $L/t31-capture.log --done $L/t31-capture.done --result-json $L/t31-capture.guard.json -- /home/victor/.cargo/bin/cargo test --release --offline --locked -j2 --no-fail-fast --manifest-path $H/Cargo.toml --lib -- token_io::capture_tests --test-threads 3 --nocapture
echo $? > $L/t31-capture.exit
cap() { # name test blocks input need cap
  local NAME=$1 TEST=$2 LB=$3 IN=$4 NEED=$5 CAP=$6
  $G --class cpu --need-gib $NEED --cap-gib $CAP --label tio-cap-$NAME --wait-secs 14400 --max-secs 3600 --log $L/cap-$NAME.log --done $L/cap-$NAME.done --result-json $L/cap-$NAME.guard.json -- /usr/bin/env HL_PB_CAPTURE_DIR=$C/$NAME HL_PB_CAPTURE_BLOCKS=$LB HL_PB_FIRST_LAYER=0 HL_PB_TOKEN_INPUT=$IN HL_RUN_CAPTURE_PUBLIC_TABLES=1 HL_TEST_SOURCE_COMMIT=uncommitted-token-io-r7d /home/victor/.cargo/bin/cargo test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib private_block::token_io::capture_tests::$TEST -- --ignored --nocapture
  echo $? > $L/cap-$NAME.exit
}
if [ "$(cat $L/t31-capture.exit)" = "0" ]; then
  cap tinyllama-t32-L22-dense-pt1 capture_a_tinyllama_token_run 22 dense 5 7
  cap tinyllama-t32-L22-fixed-pt1 capture_a_tinyllama_token_run 22 fixed 5 7
  cap llama3-8b-t32-L1-dense-pt1 capture_a_llama3_8b_token_run 1 dense 7 9
  cap llama3-8b-t32-L1-fixed-pt1 capture_a_llama3_8b_token_run 1 fixed 7 9
fi
echo done > $L/r7d_chain.done
