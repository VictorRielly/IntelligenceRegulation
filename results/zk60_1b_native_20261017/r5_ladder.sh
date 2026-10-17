#!/bin/bash
# NATIVE LANE, speed plan task 3 (2026-10-17 evening): ONE generic dense
# Llama-3-8B block at T (64|128), CPU or GPU arm (ONE GPU pass per
# invocation; HL_GPU_REQUIRED=1; commitments on the device), HL_PB_TIMING=1,
# RAYON_NUM_THREADS=16, as a guarded release test; then a FRESH-process
# verify of the saved segment by the CPU test binary (with the verifier
# controls). The CPU arm also runs every prove-side control; the GPU arm
# skips them (ZK60_NATIVE_LADDER_NO_CONTROLS=1: the same block, the controls
# are the CPU arm's).
# 21:30 UTC: the test binaries are COPIED once (CPU: the one `t3-lib` built;
# GPU: the one `t3-gpu-testbuild` built) into r5/ladder8b-testbin/ and run
# DIRECTLY, so a later source edit can never trigger a rebuild inside a
# guarded run (the T64 / T128 CPU arms ran through `cargo test` on the same
# CPU binary, hashline-a876d33e95d2a941).
# usage: r5_ladder.sh <T> cpu|gpu <need> <cap>
set -u
D=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
T=$1; MODE=$2; NEED=$3; CAP=$4
R=$D/r5/ladder8b-T$T-$MODE
B=$D/r5/ladder8b-testbin
mkdir -p "$R" "$B"
copy_bin() {  # $1 = build log, $2 = destination
  [ -f "$2" ] && return 0
  local p
  p=$(grep -o "unittests src/lib.rs ([^)]*)" "$1" | head -1 | sed 's/.*(\(.*\))/\1/')
  [ -n "$p" ] && [ -x "$p" ] || { echo "no lib test binary named in $1"; return 1; }
  cp "$p" "$2" && sha256sum "$2" >> $B/binaries.sha256 && echo "$p" > "$2.source"
}
copy_bin $D/t3-lib.log $B/lib-test.cpu || exit 1
PROVE=private_block::ladder8b_tests::native_ladder8b_generic_block_proves_verifies_and_every_control_refuses
VERIFY=private_block::ladder8b_tests::native_ladder8b_verify_the_saved_segment_in_a_fresh_process
if [ "$MODE" = gpu ]; then
  copy_bin $D/t3-gpu-testbuild.log $B/lib-test.gpu || exit 1
  python3 $G run --class gpu --need-gib $NEED --cap-gib $CAP --label r5-ladder8b-T$T-gpu --wait-secs 14400 --max-secs 3600 \
    --log "$R/prove.log" --done "$R/prove.done" --result-json "$R/prove.guard.json" \
    -- /usr/bin/env HL_PB_TIMING=1 HL_GPU=1 HL_GPU_REQUIRED=1 RAYON_NUM_THREADS=16 ZK60_NATIVE_LADDER_T=$T ZK60_NATIVE_LADDER_DIR=$R ZK60_NATIVE_LADDER_NO_CONTROLS=1 \
       CUDA_ROOT=/home/victor/cuda-root LD_LIBRARY_PATH=$LD \
       $B/lib-test.gpu --ignored --exact $PROVE --nocapture --test-threads=1
else
  python3 $G run --class cpu --need-gib $NEED --cap-gib $CAP --label r5-ladder8b-T$T-cpu --wait-secs 14400 --max-secs 3600 \
    --log "$R/prove.log" --done "$R/prove.done" --result-json "$R/prove.guard.json" \
    -- /usr/bin/env HL_PB_TIMING=1 RAYON_NUM_THREADS=16 ZK60_NATIVE_LADDER_T=$T ZK60_NATIVE_LADDER_DIR=$R \
       $B/lib-test.cpu --ignored --exact $PROVE --nocapture --test-threads=1
fi
rc=$?
[ $rc -eq 0 ] || { echo "ladder8b T$T $MODE prove exit $rc"; exit $rc; }
python3 $G run --class cpu --need-gib ${VNEED:-3} --cap-gib ${VCAP:-6} --label r5-ladder8b-verify-T$T-$MODE --wait-secs 14400 --max-secs 3600 \
  --log "$R/verify.log" --done "$R/verify.done" --result-json "$R/verify.guard.json" \
  -- /usr/bin/env HL_PB_TIMING=1 RAYON_NUM_THREADS=16 ZK60_NATIVE_LADDER_T=$T ZK60_NATIVE_LADDER_DIR=$R \
     $B/lib-test.cpu --ignored --exact $VERIFY --nocapture --test-threads=1
echo "ladder8b T$T $MODE verify exit $?"
