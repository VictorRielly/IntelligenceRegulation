#!/bin/bash
# W16 privacy gate (D54 re-check, tooling step) gate chain: the plane index and recorder taught W16's
# range histograms, their table helpers and range tables; the W16 privacy gate checks at the rung and
# at the two trained T128 shapes. Template: m22f3_gates.sh.
set -u
export ZK60_GUARD_POLL_SECS=0.05
R=/Users/victorrielly/IntelligenceRegulation
G="python3 $R/scripts/zk60_resource_guard.py run"
L=$R/results/zk60_metal_20261031/logs/m23pg
H=$R/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
F=$R/results/zk60_1b_native_20261017/r13/loader-fixtures
T=private_block::slot_ir::accuracy::tests
mkdir -p $L
step() { echo "== $1 $(date +%H:%M:%S)"; }

step build
$G --class build --need-gib 4 --cap-gib 10 --label m23pg-build --wait-secs 7200 --max-secs 3600 --log $L/g_build.log --done $L/g_build.done -- \
  bash -c "cargo test --release --features gpu-metal --manifest-path $H --lib --no-run && cargo check --release --manifest-path $H --lib --tests" \
  || { grep -E -A12 '^(error|warning)' $L/g_build.log | tail -60; exit 1; }
grep -c "^warning" $L/g_build.log
# the test binary's hash moves with the build: read it from this build's log
REL=$(grep -E -o 'target/release/deps/hashline-[0-9a-f]{16}' $L/g_build.log | tail -1)
[ -n "$REL" ] || { echo "NO TEST BINARY IN THE BUILD LOG"; exit 1; }
B=$R/ops/zkp-mvp/gpu-metal/hashline/$REL
echo "B=$B"
ls -la $B || exit 1
sleep 10
step zkp-core
ZC=$R/ops/zkp-mvp/gpu-metal/zkp-core/Cargo.toml
$G --class build --need-gib 4 --cap-gib 10 --label m23pg-zkpcore --wait-secs 7200 --max-secs 3600 --log $L/g_zkpcore.log --done $L/g_zkpcore.done -- \
  cargo test --release --manifest-path $ZC --lib -- m8_ fold eq_table transcript path merkle tree
grep -h "test result\|FAILED\|panicked" $L/g_zkpcore.log | tail -3
grep -q "test result: ok" $L/g_zkpcore.log || exit 1

for tail in default 0; do
  sleep 10
  step bytes-$tail
  E="env HL_GPU_REQUIRED=1"; [ $tail = 0 ] && E="$E HL_METAL_BATCH_TAIL_US=0"
  $G --class gpu --need-gib 60 --cap-gib 160 --label m23pg-bytes-$tail --wait-secs 7200 --max-secs 3000 --log $L/g_bytes_$tail.log --done $L/g_bytes_$tail.done -- \
    $E HL_METAL_TIMING=0 $B --ignored --exact --nocapture --test-threads=1 $T::m4_accuracy_block_proofs_are_byte_identical_on_the_cpu_and_on_metal
  grep -h -o -E "M4-ACCURACY-DIGEST [A-Z0-9_]+ cpu [0-9a-f]{8}|test result.*|panicked.*" $L/g_bytes_$tail.log
  for d in "R13_RUNG_LOW cpu 01fa1b2e" "R13_RUNG_H24 cpu 992034f8" "R13_RUNG_LOW_DD cpu 371e6b00" "R13_RUNG_H24_DD cpu 3ab090df"; do
    grep -q "M4-ACCURACY-DIGEST $d" $L/g_bytes_$tail.log || { echo "BYTES MOVED: $d"; exit 1; }
  done
  grep -q "test result: ok" $L/g_bytes_$tail.log || exit 1
done

# the unit set of m22f3, plus the W16 gate, every run-capture test (plane index, allow-list, replay,
# array store) and the R13 classifier capture tests (plane index at R13, statement-table replay)
for tail in default 0; do
  sleep 10
  step unit-$tail
  E="env HL_R13_LOADER_FIXTURES=$F"; [ $tail = 0 ] && E="$E HL_METAL_BATCH_TAIL_US=0"
  $G --class cpu --need-gib 8 --cap-gib 40 --label m23pg-unit-$tail --wait-secs 7200 --max-secs 3000 --log $L/g_unit_$tail.log --done $L/g_unit_$tail.done -- \
    $E $B w16_privacy_gate run_capture_tests r17_ plane_index w16_f3_ w16_review review_r2 range16 the_range_tags layout m15_ accuracy_act m6_ m5c_ m4c_ m4d_ m4h_ m4i_ m4j_ s28 s29 slot_ir metal range16 accuracy_layout accuracy_profile
  grep -h "test result\|FAILED\|panicked" $L/g_unit_$tail.log | grep -v "layout.rs:481" | tail -4
  grep -q "test result: ok" $L/g_unit_$tail.log || exit 1
done

# the W16 privacy gate at the rung once more with its output, for the record
sleep 10
step pg-rung
$G --class cpu --need-gib 8 --cap-gib 40 --label m23pg-rung --wait-secs 7200 --max-secs 3000 --log $L/g_pg_rung.log --done $L/g_pg_rung.done -- \
  $B w16_privacy_gate_at_the_development_rung --nocapture --test-threads=1
grep -h "W16-PG\|test result\|FAILED\|panicked" $L/g_pg_rung.log | cut -c1-500
grep -q "test result: ok. 1 passed" $L/g_pg_rung.log || exit 1

# and at the two trained T128 shapes, two hidden inputs each
sleep 10
step pg-t128
$G --class cpu --need-gib 24 --cap-gib 80 --label m23pg-t128 --wait-secs 7200 --max-secs 3000 --log $L/g_pg_t128.log --done $L/g_pg_t128.done -- \
  env HL_W16PG_PAIR=1 $B --ignored --exact --nocapture --test-threads=1 private_block::w16_privacy_gate_tests::w16_privacy_gate_at_the_trained_t128_shapes
grep -h "W16-PG\|test result\|FAILED\|panicked" $L/g_pg_t128.log | cut -c1-500
grep -q "test result: ok. 1 passed" $L/g_pg_t128.log || exit 1

sleep 10
step trained
$G --class gpu --need-gib 60 --cap-gib 160 --label m23pg-trained --wait-secs 7200 --max-secs 3000 --log $L/g_trained.log --done $L/g_trained.done -- \
  env HL_GPU_REQUIRED=1 HL_M4_PHASES=1 HL_M4_WARM_PASSES=3 HL_M4_PROFILES=R13_SHIELD_T128_H24,R13_8B_T128_H24,W16_SHIELD_T128_H24,W16_8B_T128_H24 $B --ignored --exact --nocapture --test-threads=1 $T::m4_trained_accuracy_block_cpu_and_metal_digests_and_times
grep -h "M4-TRAINED.*metal-warm\|test result\|FAILED\|panicked" $L/g_trained.log | cut -c1-260
grep -q "M4-TRAINED R13_SHIELD_T128_H24 .*digest cpu 2b0d04bb" $L/g_trained.log || { echo "SHIELD DIGEST MOVED"; exit 1; }
grep -q "M4-TRAINED R13_8B_T128_H24 .*digest cpu 678953f6" $L/g_trained.log || { echo "8B DIGEST MOVED"; exit 1; }
grep -q "M4-TRAINED W16_SHIELD_T128_H24 .*digest cpu 01a6d51d" $L/g_trained.log || { echo "W16 SHIELD DIGEST MOVED"; exit 1; }
grep -q "M4-TRAINED W16_8B_T128_H24 .*digest cpu c5e0bdac" $L/g_trained.log || { echo "W16 8B DIGEST MOVED"; exit 1; }
grep -q "test result: ok" $L/g_trained.log || exit 1

sleep 10
step r13
$G --class gpu --need-gib 8 --cap-gib 40 --label m23pg-r13 --wait-secs 7200 --max-secs 3000 --log $L/g_r13.log --done $L/g_r13.done -- \
  env HL_GPU=1 HL_GPU_REQUIRED=1 HL_R13_LOADER_FIXTURES=$F $B r16_an_r13_classifier_run_with_two_gate_denominators_proves_and_verifies --nocapture --test-threads=1
grep -h "test result\|FAILED\|panicked" $L/g_r13.log | tail -2
grep -q "test result: ok. 1 passed" $L/g_r13.log || exit 1

sleep 10
step golden
python3 $R/results/zk60_metal_20261031/run_golden.py --child --bin $B
cat $R/results/zk60_metal_20261031/logs/golden.done
grep -q "^ALL 0" $R/results/zk60_metal_20261031/logs/golden.done || exit 1

step done
