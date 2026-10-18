#!/bin/bash
# Stage R3-C (review round 2): t16 token_io + every census; if green, the generic 8B run again
# (its parameter line moved: t17 prove, t18 fresh verify), then s4 the full suite. Each leaf guarded.
R=/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017
L=$R/logs
G="python3 /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
C="/home/victor/.cargo/bin/cargo test --release --offline --locked -j2 --manifest-path /home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io/hashline/Cargo.toml"
g() { # label need cap max -- cmd...
  local lab=$1 need=$2 cap=$3 max=$4; shift 5
  $G --class cpu --need-gib $need --cap-gib $cap --label tio-$lab --wait-secs 14400 --max-secs $max --log $L/$lab.log --done $L/$lab.done --result-json $L/$lab.guard.json -- "$@"
  echo $? > $L/$lab.exit
}
g t16-r3c-built 5 7 1800 -- $C --no-fail-fast --lib -- token_io s24_tests s25_tests s33_tests hash_domain run_capture_tests::the --test-threads 4 --nocapture
if [ "$(cat $L/t16-r3c-built.exit)" = "0" ]; then
  rm -rf $R/runs/r3/generic-ho00
  g t17-r3-prove 4.5 6.5 1800 -- /usr/bin/env TOKEN_IO_R3_OUT=$R/runs/r3 TOKEN_IO_R3_SEQ=ho00 $C --lib -- token_io_r3_prove_to_dir --ignored --nocapture --test-threads 1
  if [ "$(cat $L/t17-r3-prove.exit)" = "0" ]; then
    g t18-r3-verify 4 6 1800 -- /usr/bin/env TOKEN_IO_R3_OUT=$R/runs/r3 TOKEN_IO_R3_SEQ=ho00 $C --lib -- token_io_r3_verify_from_dir --ignored --nocapture --test-threads 1
  fi
  g s4-suite 5 8 2700 -- $C --no-fail-fast -- --test-threads=8
fi
echo done > $L/r3c_chain.done
