#!/bin/bash
# Round 7, item 4 step A: after the demo's full suite (s9) has finished, sync the capture work from
# wip-r7c/ into the lane's working copy, run t30 (every token_io test, the new capture tests and the
# block run-capture tests), rebuild the release CLI and compare it byte for byte with the r7 demo binary
# (the hooks are cfg(test): the production binary must not move), then take the gate's TinyLlama
# captures at L = 1 and 2, dense and fixed, with the public tables' values, into
# $HOME/zk60-artifacts/token-io/captures/ (outside the repository).
R=/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017
L=$R/logs
D=$R/cli
H=/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io/hashline
W=$R/wip-r7c
C=/home/victor/zk60-artifacts/token-io/captures
G="python3 /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
until [ -f $L/r7_cli_demo.done ]; do sleep 30; done
for f in run_capture.rs run.rs token_io.rs token_io/run.rs token_io/stage_in.rs token_io/stage_out.rs token_io/capture_tests.rs; do
  cp $W/private_block/$f $H/src/private_block/$f
done
python3 $R/tools/manifest.py $R/manifest_r7C.sha256 $R/manifest_r7_demo.sha256 > $L/r7c-sync.log 2>&1
date -u +%H:%M:%S >> $L/r7c-sync.log
$G --class cpu --need-gib 4 --cap-gib 6 --label tio-t30-capture --wait-secs 14400 --max-secs 2700 --log $L/t30-capture.log --done $L/t30-capture.done --result-json $L/t30-capture.guard.json -- /home/victor/.cargo/bin/cargo test --release --offline --locked -j2 --no-fail-fast --manifest-path $H/Cargo.toml --lib -- token_io run_capture --test-threads 4 --nocapture
echo $? > $L/t30-capture.exit
if [ "$(cat $L/t30-capture.exit)" = "0" ]; then
  $G --class build --need-gib 3 --cap-gib 5 --label tio-r7c-cli-build --wait-secs 14400 --max-secs 1800 --log $L/r7c-cli-build.log --done $L/r7c-cli-build.done --result-json $L/r7c-cli-build.guard.json -- /home/victor/.cargo/bin/cargo build --release --offline --locked -j2 --manifest-path $H/Cargo.toml --example zk60_token_io
  echo $? > $L/r7c-cli-build.exit
  cp $H/target/release/examples/zk60_token_io $D/zk60_token_io.r7c.release.bin
  sha256sum $D/zk60_token_io.r7c.release.bin $D/zk60_token_io.r7.release.bin > $L/r7c-binary-compare.txt
  mkdir -p -m 700 $C
  for LB in 1 2; do
    for IN in dense fixed; do
      NAME=tinyllama-t32-L$LB-$IN-pt1
      $G --class cpu --need-gib 4 --cap-gib 6 --label tio-cap-$NAME --wait-secs 14400 --max-secs 2700 --log $L/cap-$NAME.log --done $L/cap-$NAME.done --result-json $L/cap-$NAME.guard.json -- /usr/bin/env HL_PB_CAPTURE_DIR=$C/$NAME HL_PB_CAPTURE_BLOCKS=$LB HL_PB_FIRST_LAYER=0 HL_PB_TOKEN_INPUT=$IN HL_RUN_CAPTURE_PUBLIC_TABLES=1 HL_TEST_SOURCE_COMMIT=uncommitted-token-io-r7c /home/victor/.cargo/bin/cargo test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib private_block::token_io::capture_tests::capture_a_tinyllama_token_run -- --ignored --nocapture
      echo $? > $L/cap-$NAME.exit
    done
  done
fi
echo done > $L/r7c_chain.done
