#!/bin/bash
# Post-merge check: gate round 26 wiring (F-B1 pins + proved_on_gpu, R26 readings in the v25 gate) on the main checkout.
set -u
export ZK60_GUARD_POLL_SECS=0.05
R=/Users/victorrielly/IntelligenceRegulation
G="python3 $R/scripts/zk60_resource_guard.py run"
L=$R/results/zk60_metal_20261031/logs/m31r26merge
F=$R/results/zk60_1b_native_20261017/r13/loader-fixtures
mkdir -p $L
H=$R/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
step() { echo "== $1 $(date +%H:%M:%S)"; }
step build
$G --class build --need-gib 4 --cap-gib 10 --label m31-build --wait-secs 7200 --max-secs 3600 --log $L/build.log --done $L/build.done -- \
  bash -c "cargo test --release --features gpu-metal --manifest-path $H --lib --no-run && cargo check --release --manifest-path $H --lib --tests" \
  || { grep -E -A12 '^(error|warning: unused)' $L/build.log | tail -60; exit 1; }
B=$(grep -o -E 'target/release/deps/hashline-[0-9a-f]+' $L/build.log | tail -1); B=$R/ops/zkp-mvp/gpu-metal/hashline/$B
ls -la $B || exit 1
echo "warnings: $(grep -c '^warning' $L/build.log)"
sleep 5
step targeted
$G --class gpu --need-gib 30 --cap-gib 120 --label m31-tests --wait-secs 7200 --max-secs 3600 --log $L/tests.log --done $L/tests.done -- \
  env HL_GPU_REQUIRED=1 HL_R13_LOADER_FIXTURES=$F $B --test-threads=4 w16r2 run::fork w16_privacy_gate range16 s24_tests s25_tests s33_tests hash_domain r19b absorb d60 run_capture
grep -h "test result\|FAILED\|panicked" $L/tests.log | tail -8
step bytes
$G --class gpu --need-gib 60 --cap-gib 160 --label m31-bytes --wait-secs 7200 --max-secs 3000 --log $L/bytes.log --done $L/bytes.done -- \
  env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $B --ignored --exact --nocapture --test-threads=1 private_block::slot_ir::accuracy::tests::m4_accuracy_block_proofs_are_byte_identical_on_the_cpu_and_on_metal
grep -h -o -E "M4-ACCURACY-DIGEST [A-Z0-9_]+ cpu [0-9a-f]{8}|test result.*" $L/bytes.log
sleep 5
step pysuite
PY=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/gatevenv/bin/python3
BR=/Users/victorrielly/zk60-artifacts/d60_20261102/pg_bundles_r26
O=/Users/victorrielly/zk60-artifacts/d60_20261102/pg_bundles
W=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/bundles
$G --class cpu --need-gib 4 --cap-gib 24 --label m31-py --wait-secs 7200 --max-secs 3600 --log $L/py.log --done $L/py.done -- \
  env ZK60_W16_RUNG_BUNDLE=$W/w16_rung_h24-s0 ZK60_W16R2_RUNG_BUNDLE=$W/w16r2_rung_h24-s0 ZK60_D55_BUNDLE=$W/d55-w16_rung_h24-s0 \
  ZK60_D55_R13_BUNDLE=$BR/d55-r13_rung_h24-s0 ZK60_D55_R13_OTHER=$BR/d55-r13_rung_h24-s1 ZK60_D60_OLD_BUNDLE=$O/d55-r13_rung_h24-s0 \
  $PY -B -m unittest discover -s $R/ops/zkp-mvp/gate-tinyllama/staging_v25/tests -v
grep -E "^(FAIL|ERROR):|^Ran |^OK|^FAILED" $L/py.log
step full-suite
$G --class cpu --need-gib 24 --cap-gib 160 --label m31-full --wait-secs 7200 --max-secs 7200 --log $L/full.log --done $L/full.done -- \
  env HL_R13_LOADER_FIXTURES=$F $B --test-threads=8
grep -h "test result" $L/full.log
echo "full-suite failures:"; grep -E '^test .* \.\.\. FAILED$' $L/full.log | awk '{print $2}' | sort
step done
