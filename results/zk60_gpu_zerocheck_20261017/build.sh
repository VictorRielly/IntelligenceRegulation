#!/bin/bash
# GPU ZERO-CHECK lane (2026-10-17): guarded builds of the lane copy
# ops/zkp-mvp/gpu-zerocheck (gpu-cuda feature, own target dir).
# usage: build.sh <label> <mode>   mode: example | testbin-debug | testbin-release
set -u
L=$1; M=$2
E=/home/victor/IntelligenceRegulation/results/zk60_gpu_zerocheck_20261017/logs
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
W=/home/victor/IntelligenceRegulation/ops/zkp-mvp/gpu-zerocheck/hashline
LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
ENVS="CUDA_ROOT=/home/victor/cuda-root LD_LIBRARY_PATH=$LD CARGO_TARGET_DIR=$W/target-gpu"
C="/home/victor/.cargo/bin/cargo"
case "$M" in
  example) ARGS="build --release --offline --locked -j2 --manifest-path $W/Cargo.toml --features gpu-cuda --example zk60_trained_block" ;;
  testbin-debug) ARGS="test --offline --locked -j2 --manifest-path $W/Cargo.toml --features gpu-cuda --lib --no-run" ;;
  testbin-release) ARGS="test --release --offline --locked -j2 --manifest-path $W/Cargo.toml --features gpu-cuda --lib --no-run" ;;
  check-gpu) ARGS="check --offline --locked -j2 --manifest-path $W/Cargo.toml --features gpu-cuda --lib --tests --message-format short" ;;
  check-cpu) ENVS="CARGO_TARGET_DIR=$W/target"; ARGS="check --offline --locked -j2 --manifest-path $W/Cargo.toml --lib --tests --message-format short" ;;
  *) echo "bad mode"; exit 2 ;;
esac
python3 $G run --class build --need-gib 3 --cap-gib 5 --label "$L" --wait-secs 7200 --max-secs 3600 \
  --log "$E/$L.log" --done "$E/$L.done" --result-json "$E/$L.guard.json" \
  -- /usr/bin/env $ENVS $C $ARGS
