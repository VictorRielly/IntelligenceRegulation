#!/bin/bash
# D24 review R13 (accuracy stack, frozen bb9eb212...): serial guarded queue.
# Lean-memory rule: only the goldens job declares >= 3 GiB (7.5); it waits for a
# box with no other >= 3 GiB job (checked before launch) and every heavy job is
# followed by a 60 s gap so a waiting sol-/astra-/release job can take the lock.
# Read only on every other lane's tree; Sol's receipts/exports are verified from
# copies in my scratch. One checkpoint stream only (rv13-shield).
set -u
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
R=/home/victor/IntelligenceRegulation/results/zk60_d24_review_20261017/r13
S=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-review-r13-scratch
T=$S/tree
C=/home/victor/.cargo/bin/cargo
N=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017
HOLD=/home/victor/IntelligenceRegulation/results/zk60_guard_fix_20261021/WINDOW_HOLD
Q=$R/queue.out
STAGE=${1:-all}
log() { echo "[$(date -u +%H:%M:%SZ)] $*" >> $Q; }
hold() { while [ -e $HOLD ]; do sleep 30; done; }
gap() { sleep 60; }
guard() { local cl=$1 need=$2 cap=$3 maxs=$4 label=$5; shift 5
  hold
  python3 $G run --class $cl --need-gib $need --cap-gib $cap --label $label --wait-secs 21600 --max-secs $maxs \
    --log $R/$label.log --done $R/$label.done --result-json $R/$label.guard.json -- "$@"
  log "$label exit $(cat $R/$label.done)"; }
ENVS="RAYON_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1 ZK60_NATIVE_TINY_EXPORT_DIR=$S/review_tmp RV13_EVIDENCE=$R"
log "queue start stage=$STAGE"
if [ "$STAGE" = all ] || [ "$STAGE" = a ]; then
  guard build 2.5 4.5 3600 rv13-test-build $C test --release --offline --locked -j2 --manifest-path $T/hashline/Cargo.toml --lib --no-run
  [ "$(cat $R/rv13-test-build.done)" = 0 ] || { log "test build failed"; echo testbuild-fail > $R/r13_queue.done; exit 1; }
  gap
  guard build 2.5 4.5 3600 rv13-cli-build $C build --release --offline --locked -j2 --manifest-path $T/hashline/Cargo.toml --example zk60_trained_block
  gap
fi
BIN=$T/hashline/$(grep -o "target/release/deps/hashline-[0-9a-f]*" $R/rv13-test-build.log | tail -1)
X=$T/hashline/target/release/examples/zk60_trained_block
sha256sum $BIN $X > $R/binaries.sha256
log "lib test binary: $BIN"
if [ "$STAGE" = all ] || [ "$STAGE" = a ]; then
  guard cpu 1.5 3 3600 rv13-review /usr/bin/env $ENVS $BIN --ignored --test-threads=1 --nocapture review_r13_tests::rv13_ --skip rv13_shieldstral
  gap
  guard cpu 1.5 3 3600 rv13-sol-attacks /usr/bin/env $ENVS $BIN --ignored --test-threads=1 --nocapture accuracy_proof_tests:: --skip accuracy_actual_shieldstral
  gap
  guard cpu 1.0 3 1800 rv13-components /usr/bin/env $ENVS $BIN --test-threads=4 accuracy
  for v in r13-low-dense-plain:r13-low-dense:2f386a9fd7480b2d8bcca4064e679e204ba2068358bd50677e7f6bf54feb6dbd: \
           r13-low-dense-dd:r13-low-dense:62d849886e90b7d3f6595f33fb8bff5e6b9009c6c3b34e5979ed4f9bd46666d5:--dd \
           r13-h24-wide-plain:r13-h24-wide:6ac6d19087ee02ba9f87bcc6f772404b23726c293dd213b04d7392dc7f519b5b: \
           r13-h24-wide-dd:r13-h24-wide:1fc37b86657ad43d2fa2025a99312d796b4f76cafcacabd2b779219221010ff3:--dd; do
    IFS=: read rec exp id dd <<< "$v"
    guard cpu 1.0 3 900 rv13-cli-$rec /usr/bin/env RAYON_NUM_THREADS=4 $X verify --export $S/sol-exports/$exp --layer 0 --artifact $S/sol-receipts/$rec --expect-statement $id --controls $dd
  done
  guard cpu 1.2 3 1800 rv13-compat-tl-dd /usr/bin/env RAYON_NUM_THREADS=8 $X stack-verify --export $N/r9/verifier-exports/tinyllama_dg_rot1_T128 --artifact $N/r9/stack-tinyllama_dg_rot1_T128-ho00-cpu-dd/run --expect-statement d57212761b29a8eab43d03af012a3b5bec7154455786275f4000502893d22e4b --dd
  guard cpu 2.7 4 2400 rv13-compat-8b-dd /usr/bin/env RAYON_NUM_THREADS=8 $X stack-verify --export $N/r9/verifier-exports/llama3_8b_pg_rot1_b7voc0_T128 --artifact $N/r9/stack-llama3_8b_pg_rot1_b7voc0_T128-ho00-cpu-dd/run --expect-statement 4da580bdda8b9e4aef4ceb281e2b31e8008d99425d2601553b38f753b1492520 --dd
  guard cpu 1.2 3 1800 rv13-compat-tl /usr/bin/env RAYON_NUM_THREADS=8 $X stack-verify --export $N/r8/verifier-exports/tinyllama_dg_rot1_T128 --artifact $N/r8/stack-tinyllama_dg_rot1_T128-ho00-cpu/run --expect-statement caf6ced22fbb87a94c1f571a96faf278815668996863146805c9d2eea76c9165
  guard cpu 2.7 4 2400 rv13-compat-8b /usr/bin/env RAYON_NUM_THREADS=8 $X stack-verify --export $N/r8/verifier-exports/llama3_8b_pg_rot1_b7voc0_T128 --artifact $N/r8/stack-llama3_8b_pg_rot1_b7voc0_T128-ho00-cpu/run --expect-statement 5585f5eed7a24a559ce76ddbd0413ddffd877637efb07d29bbd9408b4fc5a3b4
  gap
fi
if [ "$STAGE" = b ]; then
  guard build 2.5 4.5 3600 rv13-test-build-2 $C test --release --offline --locked -j2 --manifest-path $T/hashline/Cargo.toml --lib --no-run
  [ "$(cat $R/rv13-test-build-2.done)" = 0 ] || { log "test build 2 failed"; echo testbuild2-fail > $R/r13_queue.done; exit 1; }
  BIN=$T/hashline/$(grep -o "target/release/deps/hashline-[0-9a-f]*" $R/rv13-test-build-2.log | tail -1)
  sha256sum $BIN >> $R/binaries.sha256
  log "lib test binary (2): $BIN"
  gap
  guard cpu 1.5 3 1800 rv13-controls /usr/bin/env $ENVS $BIN --ignored --exact --test-threads=1 --nocapture private_block::review_r13_tests::rv13_calibration_controls_reach_the_receipt
  gap
fi
if [ "$STAGE" = all ] || [ "$STAGE" = b ]; then
  # lean-memory rule: wait until no other job declares >= 3 GiB
  while python3 $G status 2>/dev/null | grep -E "^\s+job " | awk '{for(i=1;i<=NF;i++) if($i=="need"){v=$(i+1); sub("G","",v); if (v+0>=3) print}}' | grep -q .; do sleep 30; done
  guard cpu 7.5 9.5 1800 rv13-goldens /usr/bin/env RAYON_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1 ZK60_NATIVE_TINY_EXPORT_DIR=$S/review_tmp $BIN r12_golden_tests --ignored --test-threads=1 --nocapture
  gap
  guard cpu 2.5 4.5 2400 rv13-shield /usr/bin/env $ENVS HL_R13_SHIELDSTRAL_EXPORT=$N/shieldstral-export-v2 RV13_SHIELD_INPUT_L00=$R/shield_input_L00.bin RV13_SHIELD_INPUT_L25=$R/shield_input_L25.bin $BIN --ignored --exact --test-threads=1 --nocapture private_block::review_r13_tests::rv13_shieldstral_actual_layers_native_witness
  gap
fi
log "queue end stage=$STAGE"
echo done > $R/r13_queue.done
