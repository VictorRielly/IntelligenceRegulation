#!/bin/bash
# The generic Llama-3-8B token-I/O run (R3): prove to a directory, then a
# FRESH-process verify, each leaf guarded on its own, each with an exit file.
R=/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017
L=$R/logs
G="python3 /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
C="/home/victor/.cargo/bin/cargo test --release --offline --locked -j2 --manifest-path /home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io/hashline/Cargo.toml"
mkdir -p $R/runs/r3
g() { # label need cap max -- cmd...
  local lab=$1 need=$2 cap=$3 max=$4; shift 5
  $G --class cpu --need-gib $need --cap-gib $cap --label tio-$lab --wait-secs 10800 --max-secs $max --log $L/$lab.log --done $L/$lab.done --result-json $L/$lab.guard.json -- "$@"
  echo $? > $L/$lab.exit
}
g t14-r3-prove 4.5 6.5 1800 -- /usr/bin/env TOKEN_IO_R3_OUT=$R/runs/r3 TOKEN_IO_R3_SEQ=ho00 $C --lib -- token_io_r3_prove_to_dir --ignored --nocapture --test-threads 1
if [ "$(cat $L/t14-r3-prove.exit)" = "0" ]; then
  g t15-r3-verify 4 6 1800 -- /usr/bin/env TOKEN_IO_R3_OUT=$R/runs/r3 TOKEN_IO_R3_SEQ=ho00 $C --lib -- token_io_r3_verify_from_dir --ignored --nocapture --test-threads 1
fi
