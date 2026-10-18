#!/bin/bash
# t13b (token_io + every census) then, only if green, the generic 8B run (t14 prove, t15 fresh verify)
R=/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017
L=$R/logs
G="python3 /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
C="/home/victor/.cargo/bin/cargo test --release --offline --locked -j2 --manifest-path /home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io/hashline/Cargo.toml"
$G --class cpu --need-gib 5 --cap-gib 7 --label tio-t13b-r3-built --wait-secs 10800 --max-secs 1800 --log $L/t13b-r3-built.log --done $L/t13b-r3-built.done --result-json $L/t13b-r3-built.guard.json -- $C --no-fail-fast --lib -- token_io s24_tests s25_tests s33_tests hash_domain run_capture_tests::the --test-threads 4 --nocapture
echo $? > $L/t13b-r3-built.exit
if [ "$(cat $L/t13b-r3-built.exit)" = "0" ]; then
  $R/tools/r3_generic_run.sh
fi
echo done > $L/r3_chain.done
