#!/bin/bash
# GPU ZERO-CHECK lane: a type-check only (no codegen, ONE job), light class,
# kernel-capped at 1.5 GiB, so it may run beside another lane's heavy job.
# usage: check_light.sh <label> gpu|cpu
set -u
L=$1; M=$2
E=/home/victor/IntelligenceRegulation/results/zk60_gpu_zerocheck_20261017/logs
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
W=/home/victor/IntelligenceRegulation/ops/zkp-mvp/gpu-zerocheck/hashline
if [ "$M" = gpu ]; then
  ENVS="CUDA_ROOT=/home/victor/cuda-root CARGO_TARGET_DIR=$W/target-check-gpu"; FEAT="--features gpu-cuda"
else
  ENVS="CARGO_TARGET_DIR=$W/target-check-cpu"; FEAT=""
fi
python3 $G run --class light --need-gib 1.2 --cap-gib 1.5 --label "$L" --wait-secs 1800 --max-secs 1500 \
  --log "$E/$L.log" --done "$E/$L.done" --result-json "$E/$L.guard.json" \
  -- /usr/bin/env $ENVS /home/victor/.cargo/bin/cargo check --offline --locked -j1 --manifest-path $W/Cargo.toml $FEAT --lib --tests --message-format short
