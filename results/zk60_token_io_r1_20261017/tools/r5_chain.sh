#!/bin/bash
R=/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017
L=$R/logs
python3 /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py run --class cpu --need-gib 4 --cap-gib 6 --label tio-t25-r5-built --wait-secs 14400 --max-secs 2400 --log $L/t25-r5-built.log --done $L/t25-r5-built.done --result-json $L/t25-r5-built.guard.json -- /home/victor/.cargo/bin/cargo test --release --offline --locked -j2 --no-fail-fast --manifest-path /home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io/hashline/Cargo.toml --lib -- token_io s24_tests s25_tests s33_tests hash_domain run_capture_tests::the trained_stack_tests trained_block_tests --test-threads 4 --nocapture
echo $? > $L/t25-r5-built.exit
if [ "$(cat $L/t25-r5-built.exit)" = "0" ]; then
  $R/tools/r4_cli_demo.sh
fi
echo done > $L/r5_chain.done
