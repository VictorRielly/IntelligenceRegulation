#!/bin/bash
# D55 prototype gate chain (2026-11-01): "commit, fork, join" as an opt-in, UNREGISTERED run profile.
# Template: the M22 F3 chain (scratchpad m22f3_gates.sh), re-pointed at the D55 worktree, plus
# the prototype's own steps: the source-scan hooks, the D55 rung tests on the CPU and on Metal,
# and D12a's blocks-only R13 two-stage run test. Every leaf through the ONE shared resource guard.
set -u
export ZK60_GUARD_POLL_SECS=0.05
R=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-af0bd172154265b70
G="python3 /Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
L=$R/results/zk60_d55_20261101/logs/${1:-gates}
H=$R/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
F=$R/results/zk60_1b_native_20261017/r13/loader-fixtures
T=private_block::slot_ir::accuracy::tests
mkdir -p $L
step() { echo "== $1 $(date +%H:%M:%S)"; }

step build
$G --class build --need-gib 4 --cap-gib 10 --label d55-build --wait-secs 7200 --max-secs 3600 --log $L/g_build.log --done $L/g_build.done -- \
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
$G --class build --need-gib 4 --cap-gib 10 --label d55-zkpcore --wait-secs 7200 --max-secs 3600 --log $L/g_zkpcore.log --done $L/g_zkpcore.done -- \
  cargo test --release --manifest-path $ZC --lib -- m8_ fold eq_table transcript path merkle tree
grep -h "test result\|FAILED\|panicked" $L/g_zkpcore.log | tail -3
grep -q "test result: ok" $L/g_zkpcore.log || exit 1

# ---- D55: the source-scan hooks (the new test-only files are accounted for; no production module moved).
# Four of these five scans ALREADY FAIL at the base commit 7ee0fcda, for files of the Metal / W16 lanes
# (metal_slot.rs and range16.rs absent from the production lists; range16_tests.rs and
# w16_privacy_gate_tests.rs absent from TEST_ONLY_FILES; slot_ir.rs now on the path). The gate is therefore:
# W-8(5) passes; no scan names a D55 file; r19b's complaint is exactly those three pre-existing files.
sleep 10
step d55-hooks
$G --class cpu --need-gib 4 --cap-gib 20 --label d55-hooks --wait-secs 7200 --max-secs 1800 --log $L/g_d55_hooks.log --done $L/g_d55_hooks.done -- \
  $B r19b_every_rs_file_under_private_block the_capture_writer_pins_every_run_layer_source every_absorb_label_on_the_path_is_in_the_table no_profile_on_this_path_can_obtain_a_generator the_generator_is_never_cloned_and_each_prover_constructs_exactly_one --test-threads=1
grep -h "^test \|test result" $L/g_d55_hooks.log | tail -6
grep -q "the_generator_is_never_cloned_and_each_prover_constructs_exactly_one ... ok" $L/g_d55_hooks.log || exit 1
grep -q "run_fork" $L/g_d55_hooks.log && { echo "A SOURCE SCAN NAMES A D55 FILE"; exit 1; }
[ "$(grep 'is neither on the path nor a named test file\|is on the path AND listed' $L/g_d55_hooks.log | sort -u | wc -l | tr -d ' ')" = 3 ] || { echo "r19b's complaint is not the three pre-existing files"; exit 1; }
for f in range16_tests.rs slot_ir.rs w16_privacy_gate_tests.rs; do grep -q "src/private_block/$f is" $L/g_d55_hooks.log || { echo "r19b moved: $f"; exit 1; }; done
echo "hooks: W-8(5) ok; no scan names a D55 file; the four failing scans fail only on pre-existing Metal/W16 files"

# ---- D55: the prototype's own tests, on the CPU and with the Metal device
for arm in cpu metal; do
  sleep 10
  step d55-$arm
  if [ $arm = metal ]; then E="env HL_GPU=1 HL_GPU_REQUIRED=1 HL_R13_LOADER_FIXTURES=$F"; C=gpu; else E="env HL_R13_LOADER_FIXTURES=$F"; C=cpu; fi
  $G --class $C --need-gib 8 --cap-gib 40 --label d55-tests-$arm --wait-secs 7200 --max-secs 3000 --log $L/g_d55_$arm.log --done $L/g_d55_$arm.done -- \
    $E $B private_block::run::fork:: --nocapture --test-threads=1
  grep -h "D55 \|test result\|FAILED\|panicked" $L/g_d55_$arm.log | cut -c1-600
  grep -q "test result: ok. 7 passed" $L/g_d55_$arm.log || exit 1
done

# ---- D12a's blocks-only R13 run test (two stages, two gate denominators): unchanged
sleep 10
step d12a-run
$G --class cpu --need-gib 8 --cap-gib 40 --label d55-d12a-run --wait-secs 7200 --max-secs 3000 --log $L/g_d12a_run.log --done $L/g_d12a_run.done -- \
  env HL_R13_LOADER_FIXTURES=$F $B --ignored --exact private_block::accuracy_proof_tests::accuracy_two_stage_private_boundary_with_different_gate_shifts_verifies --nocapture --test-threads=1
grep -h "R13 two-stage\|test result\|FAILED\|panicked" $L/g_d12a_run.log | tail -3
grep -q "test result: ok. 1 passed" $L/g_d12a_run.log || exit 1

for tail in default 0; do
  sleep 10
  step bytes-$tail
  E="env HL_GPU_REQUIRED=1"; [ $tail = 0 ] && E="$E HL_METAL_BATCH_TAIL_US=0"
  $G --class gpu --need-gib 60 --cap-gib 160 --label d55-bytes-$tail --wait-secs 7200 --max-secs 3000 --log $L/g_bytes_$tail.log --done $L/g_bytes_$tail.done -- \
    $E HL_METAL_TIMING=0 $B --ignored --exact --nocapture --test-threads=1 $T::m4_accuracy_block_proofs_are_byte_identical_on_the_cpu_and_on_metal
  grep -h -o -E "M4-ACCURACY-DIGEST [A-Z0-9_]+ cpu [0-9a-f]{8}|test result.*|panicked.*" $L/g_bytes_$tail.log
  for d in "R13_RUNG_LOW cpu 01fa1b2e" "R13_RUNG_H24 cpu 992034f8" "R13_RUNG_LOW_DD cpu 371e6b00" "R13_RUNG_H24_DD cpu 3ab090df"; do
    grep -q "M4-ACCURACY-DIGEST $d" $L/g_bytes_$tail.log || { echo "BYTES MOVED: $d"; exit 1; }
  done
  grep -q "test result: ok" $L/g_bytes_$tail.log || exit 1
done

for tail in default 0; do
  sleep 10
  step unit-$tail
  E="env HL_R13_LOADER_FIXTURES=$F"; [ $tail = 0 ] && E="$E HL_METAL_BATCH_TAIL_US=0"
  $G --class cpu --need-gib 8 --cap-gib 40 --label d55-unit-$tail --wait-secs 7200 --max-secs 3000 --log $L/g_unit_$tail.log --done $L/g_unit_$tail.done -- \
    $E $B w16_f3_ w16_review review_r2 range16 the_range_tags layout m15_ accuracy_act m6_ m5c_ m4c_ m4d_ m4h_ m4i_ m4j_ s28 s29 slot_ir metal range16 accuracy_layout accuracy_profile
  grep -h "test result\|FAILED\|panicked" $L/g_unit_$tail.log | grep -v "layout.rs:481" | tail -4
  grep -q "test result: ok" $L/g_unit_$tail.log || exit 1
done

sleep 10
step trained
$G --class gpu --need-gib 60 --cap-gib 160 --label d55-trained --wait-secs 7200 --max-secs 3000 --log $L/g_trained.log --done $L/g_trained.done -- \
  env HL_GPU_REQUIRED=1 HL_M4_PHASES=1 HL_M4_WARM_PASSES=3 HL_M4_PROFILES=R13_SHIELD_T128_H24,R13_8B_T128_H24,W16_SHIELD_T128_H24,W16_8B_T128_H24 $B --ignored --exact --nocapture --test-threads=1 $T::m4_trained_accuracy_block_cpu_and_metal_digests_and_times
grep -h "M4-TRAINED.*metal-warm\|test result\|FAILED\|panicked" $L/g_trained.log | cut -c1-260
grep -q "M4-TRAINED R13_SHIELD_T128_H24 .*digest cpu 2b0d04bb" $L/g_trained.log || { echo "SHIELD DIGEST MOVED"; exit 1; }
grep -q "M4-TRAINED R13_8B_T128_H24 .*digest cpu 678953f6" $L/g_trained.log || { echo "8B DIGEST MOVED"; exit 1; }
grep -q "M4-TRAINED W16_SHIELD_T128_H24 .*digest cpu 01a6d51d" $L/g_trained.log || { echo "W16 SHIELD DIGEST MOVED"; exit 1; }
grep -q "M4-TRAINED W16_8B_T128_H24 .*digest cpu c5e0bdac" $L/g_trained.log || { echo "W16 8B DIGEST MOVED"; exit 1; }
grep -q "test result: ok" $L/g_trained.log || exit 1

sleep 10
step r13
$G --class gpu --need-gib 8 --cap-gib 40 --label d55-r13 --wait-secs 7200 --max-secs 3000 --log $L/g_r13.log --done $L/g_r13.done -- \
  env HL_GPU=1 HL_GPU_REQUIRED=1 HL_R13_LOADER_FIXTURES=$F $B r16_an_r13_classifier_run_with_two_gate_denominators_proves_and_verifies --nocapture --test-threads=1
grep -h "test result\|FAILED\|panicked" $L/g_r13.log | tail -2
grep -q "test result: ok. 1 passed" $L/g_r13.log || exit 1

sleep 10
step golden
python3 $R/results/zk60_d55_20261101/run_golden.py --child --bin $B
cat $R/results/zk60_d55_20261101/logs/golden.done
grep -q "^ALL 0" $R/results/zk60_d55_20261101/logs/golden.done || exit 1

step done
