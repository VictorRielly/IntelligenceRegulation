#!/bin/bash
# The lane's queued follow-ups after the first R2 proving run, each leaf
# guarded on its own (one heavy lock per command), each with an exit file.
R=/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017
L=$R/logs
G="python3 /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
C="/home/victor/.cargo/bin/cargo test --release --offline --locked -j2 --manifest-path /home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io/hashline/Cargo.toml"
g() { # label need cap max -- cmd...
  local lab=$1 need=$2 cap=$3 max=$4; shift 5
  $G --class cpu --need-gib $need --cap-gib $cap --label tio-$lab --wait-secs 10800 --max-secs $max --log $L/$lab.log --done $L/$lab.done --result-json $L/$lab.guard.json -- "$@"
  echo $? > $L/$lab.exit
}
g t9-r2-verify 4 7 1800 -- /usr/bin/env TOKEN_IO_R2_OUT=$R/runs/r2 TOKEN_IO_R2_SEQ=ho00 $C --lib -- token_io_r2_verify_from_dir --ignored --nocapture --test-threads 1
g t10-r1-prove 3 6 1200 -- /usr/bin/env TOKEN_IO_R1_OUT=$R/runs $C --lib -- token_io_r1_prove_to_dir --ignored --nocapture --test-threads 1
g t11-r1-verify 3 6 1200 -- /usr/bin/env TOKEN_IO_R1_OUT=$R/runs $C --lib -- token_io_r1_verify_from_dir --ignored --nocapture --test-threads 1
g s3-suite 5 8 2700 -- $C --no-fail-fast -- --test-threads=8
