#!/bin/bash
# Round 6: wait for the failing-first run t26 (T-A) to finish, sync T-B from wip-r6b/ into the lane's
# working copy, run t27 (token_io + every census + the native trained CLI tests), and if green the
# round-6 8B CLI demo (tools/r4_cli_demo.sh, TAG=r6, which ends with the full suite s8).
R=/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017
L=$R/logs
H=/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io/hashline
W=$R/wip-r6b
until [ -f $L/t26-tr5-failfirst.done ]; do sleep 30; done
cp $W/src/private_block/token_io/cli.rs $H/src/private_block/token_io/cli.rs
cp $W/src/private_block/token_io/cli_tests.rs $H/src/private_block/token_io/cli_tests.rs
cp $W/examples/zk60_token_io.rs $H/examples/zk60_token_io.rs
python3 $R/tools/manifest.py $R/manifest_r6B.sha256 $R/manifest_r6A.sha256 > $L/r6-sync.log 2>&1
date -u +%H:%M:%S >> $L/r6-sync.log
python3 /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py run --class cpu --need-gib 4 --cap-gib 6 --label tio-t27-r6-built --wait-secs 14400 --max-secs 2400 --log $L/t27-r6-built.log --done $L/t27-r6-built.done --result-json $L/t27-r6-built.guard.json -- /home/victor/.cargo/bin/cargo test --release --offline --locked -j2 --no-fail-fast --manifest-path $H/Cargo.toml --lib -- token_io s24_tests s25_tests s33_tests hash_domain run_capture_tests::the trained_stack_tests trained_block_tests --test-threads 4 --nocapture
echo $? > $L/t27-r6-built.exit
if [ "$(cat $L/t27-r6-built.exit)" = "0" ]; then
  /usr/bin/env TAG=r6 $R/tools/r4_cli_demo.sh
fi
echo done > $L/r6_chain.done
