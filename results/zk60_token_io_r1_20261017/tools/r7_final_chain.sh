#!/bin/bash
# Round 7 close: the 8B captures at L = 2 (an internal boundary at the 8B geometry; L = 1 held 3.2 GiB),
# then the full suite (s10) on the final tree (manifest_r7D).
R=/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017
L=$R/logs
H=/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io/hashline
C=/home/victor/zk60-artifacts/token-io/captures
G="python3 /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
for IN in dense fixed; do
  NAME=llama3-8b-t32-L2-$IN-pt1
  $G --class cpu --need-gib 4.5 --cap-gib 6.5 --label tio-cap-$NAME --wait-secs 14400 --max-secs 3600 --log $L/cap-$NAME.log --done $L/cap-$NAME.done --result-json $L/cap-$NAME.guard.json -- /usr/bin/env HL_PB_CAPTURE_DIR=$C/$NAME HL_PB_CAPTURE_BLOCKS=2 HL_PB_FIRST_LAYER=0 HL_PB_TOKEN_INPUT=$IN HL_RUN_CAPTURE_PUBLIC_TABLES=1 HL_TEST_SOURCE_COMMIT=uncommitted-token-io-r7d /home/victor/.cargo/bin/cargo test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib private_block::token_io::capture_tests::capture_a_llama3_8b_token_run -- --ignored --nocapture
  echo $? > $L/cap-$NAME.exit
done
python3 $R/tools/manifest.py $R/manifest_final_r7.sha256 $R/manifest_r7D.sha256 $R/manifest_r7_demo.sha256 > $L/r7-final-manifest.log 2>&1
$G --class cpu --need-gib 6.5 --cap-gib 8 --label tio-s10-suite --wait-secs 14400 --max-secs 2700 --log $L/s10-suite.log --done $L/s10-suite.done --result-json $L/s10-suite.guard.json -- /home/victor/.cargo/bin/cargo test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --no-fail-fast -- --test-threads=8
echo $? > $L/s10-suite.exit
echo done > $L/r7_final_chain.done
