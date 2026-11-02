#!/bin/bash
# Post-merge check: the TS / CENSUS / bases lane and the NL-1 / preimage lane, both merged on the main checkout.
# The m31 script with two changes: the targeted step sets HL_GPU=1 with HL_GPU_REQUIRED=1 (m31's one targeted
# failure was HL_GPU_REQUIRED without HL_GPU in the F3 CLI child), and the Python suite also names the TS lane's
# eight registered-base bundles (ZK60_D55_BASE_BUNDLES). The targeted filter is m31's: `run::fork` already covers
# run_fork_tests.rs (the own-norm writer) and `s25_tests` the widened W-2 census.
set -u
export ZK60_GUARD_POLL_SECS=0.05
R=/Users/victorrielly/IntelligenceRegulation
G="python3 $R/scripts/zk60_resource_guard.py run"
L=$R/results/zk60_metal_20261031/logs/m32lanes
F=$R/results/zk60_1b_native_20261017/r13/loader-fixtures
mkdir -p $L
H=$R/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
step() { echo "== $1 $(date +%H:%M:%S)"; }
step build
$G --class build --need-gib 4 --cap-gib 10 --label m32-build --wait-secs 28800 --max-secs 3600 --log $L/build.log --done $L/build.done -- \
  bash -c "cargo test --release --features gpu-metal --manifest-path $H --lib --no-run && cargo check --release --manifest-path $H --lib --tests" \
  || { grep -E -A12 '^(error|warning: unused)' $L/build.log | tail -60; exit 1; }
B=$(grep -o -E 'target/release/deps/hashline-[0-9a-f]+' $L/build.log | tail -1); B=$R/ops/zkp-mvp/gpu-metal/hashline/$B
ls -la $B || exit 1
echo "warnings: $(grep -c '^warning' $L/build.log)"
sleep 5
step targeted
$G --class gpu --need-gib 30 --cap-gib 120 --label m32-tests --wait-secs 7200 --max-secs 3600 --log $L/tests.log --done $L/tests.done -- \
  env HL_GPU=1 HL_GPU_REQUIRED=1 HL_R13_LOADER_FIXTURES=$F $B --test-threads=4 w16r2 run::fork w16_privacy_gate range16 s24_tests s25_tests s33_tests hash_domain r19b absorb d60 run_capture
grep -h "test result\|FAILED\|panicked" $L/tests.log | tail -8
step bytes
$G --class gpu --need-gib 60 --cap-gib 160 --label m32-bytes --wait-secs 7200 --max-secs 3000 --log $L/bytes.log --done $L/bytes.done -- \
  env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $B --ignored --exact --nocapture --test-threads=1 private_block::slot_ir::accuracy::tests::m4_accuracy_block_proofs_are_byte_identical_on_the_cpu_and_on_metal
grep -h -o -E "M4-ACCURACY-DIGEST [A-Z0-9_]+ cpu [0-9a-f]{8}|test result.*" $L/bytes.log
sleep 5
step pysuite
PY=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/gatevenv/bin/python3
BR=/Users/victorrielly/zk60-artifacts/d60_20261102/pg_bundles_r26
O=/Users/victorrielly/zk60-artifacts/d60_20261102/pg_bundles
N=/Users/victorrielly/zk60-artifacts/d60_20261102/pg_bundles_bases
W=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/bundles
BASES=$N/d55-r13_tiny_t128_low-s0,$N/d55-r13_tiny_t128_low-s1,$N/d55-r13_shield_t128_h24-s0,$N/d55-r13_shield_t128_h24-s1,$N/d55-r13_shield_t128_h24-own-s0,$N/d55-r13_shield_t128_h24-own-s1,$N/d55-r13_shield_t256_h24-s0,$N/d55-r13_shield_t256_h24-s1
$G --class cpu --need-gib 8 --cap-gib 48 --label m32-py --wait-secs 7200 --max-secs 3600 --log $L/py.log --done $L/py.done -- \
  env ZK60_W16_RUNG_BUNDLE=$W/w16_rung_h24-s0 ZK60_W16R2_RUNG_BUNDLE=$W/w16r2_rung_h24-s0 ZK60_D55_BUNDLE=$W/d55-w16_rung_h24-s0 \
  ZK60_D55_R13_BUNDLE=$BR/d55-r13_rung_h24-s0 ZK60_D55_R13_OTHER=$BR/d55-r13_rung_h24-s1 ZK60_D60_OLD_BUNDLE=$O/d55-r13_rung_h24-s0 \
  ZK60_D55_BASE_BUNDLES=$BASES \
  $PY -B -m unittest discover -s $R/ops/zkp-mvp/gate-tinyllama/staging_v25/tests -v
grep -E "^(FAIL|ERROR):|^Ran |^OK|^FAILED" $L/py.log
step full-suite
$G --class cpu --need-gib 24 --cap-gib 160 --label m32-full --wait-secs 7200 --max-secs 7200 --log $L/full.log --done $L/full.done -- \
  env HL_R13_LOADER_FIXTURES=$F $B --test-threads=8
grep -h "test result" $L/full.log
echo "full-suite failures:"; grep -E '^test .* \.\.\. FAILED$' $L/full.log | awk '{print $2}' | sort
step done
