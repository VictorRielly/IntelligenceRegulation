#!/bin/bash
# Stage R3-D (rebased on the native R6 tree, per-stage score shifts): t19 token_io + every census + R6's
# own targeted filters; if green, the TRAINED Llama-3-8B run on the b7 T32 export (t20 prove, t21 fresh
# verify), then s5 the full suite. Each leaf guarded on its own.
R=/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017
L=$R/logs
E=/home/victor/IntelligenceRegulation/results/zk60_8b_calibration_20261017/export/llama3_8b_pg_rot1_b7_T32
G="python3 /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
C="/home/victor/.cargo/bin/cargo test --release --offline --locked -j2 --manifest-path /home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io/hashline/Cargo.toml"
g() { # label need cap max -- cmd...
  local lab=$1 need=$2 cap=$3 max=$4; shift 5
  $G --class cpu --need-gib $need --cap-gib $cap --label tio-$lab --wait-secs 14400 --max-secs $max --log $L/$lab.log --done $L/$lab.done --result-json $L/$lab.guard.json -- "$@"
  echo $? > $L/$lab.exit
}
g t19-r3d-built 5 7 2400 -- $C --no-fail-fast --lib -- token_io s24_tests s25_tests s33_tests hash_domain run_capture_tests::the r6_tests trained_stack_tests trained_block_tests trained_statement --test-threads 4 --nocapture
if [ "$(cat $L/t19-r3d-built.exit)" = "0" ]; then
  g t20-r3-trained-prove 4.5 6.5 1800 -- /usr/bin/env TOKEN_IO_R3_OUT=$R/runs/r3 TOKEN_IO_R3_SEQ=ho00 TOKEN_IO_R3_EXPORT=$E TOKEN_IO_R3_EMB=$E/token_io TOKEN_IO_R3_HEAD=$E/token_io $C --lib -- token_io_r3_prove_to_dir --ignored --nocapture --test-threads 1
  if [ "$(cat $L/t20-r3-trained-prove.exit)" = "0" ]; then
    g t21-r3-trained-verify 4 6 1800 -- /usr/bin/env TOKEN_IO_R3_OUT=$R/runs/r3 TOKEN_IO_R3_SEQ=ho00 TOKEN_IO_R3_EXPORT=$E TOKEN_IO_R3_EMB=$E/token_io TOKEN_IO_R3_HEAD=$E/token_io $C --lib -- token_io_r3_verify_from_dir --ignored --nocapture --test-threads 1
  fi
  g s5-suite 6.5 8 2700 -- $C --no-fail-fast -- --test-threads=8
fi
echo done > $L/r3d_chain.done
