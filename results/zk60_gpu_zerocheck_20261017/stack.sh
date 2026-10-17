#!/bin/bash
# GPU ZERO-CHECK lane: ONE 22-block TinyLlama T128 stack (pg_rot1_b4_T128,
# ho00) on the GPU arm with the phase clock, the lane's gpu-cuda CLI.
# ONE run per invocation (never chain GPU passes). Capped at 30 minutes.
# VRAM: the baseline GPU-arm T128 stack peaked at 3,105 MiB; the device
# slot 18 adds its 21 x 2^20 Fp2 tables (336 MiB, reused across blocks by
# the pool's exact-length match), so ~3.45 GiB expected (lane limit 4 GiB).
# usage: stack.sh <tag> <HL_GPU_ZEROCHECK 0|1> [extra env VAR=value ...]
set -u
D=/home/victor/IntelligenceRegulation/results/zk60_gpu_zerocheck_20261017
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
E=${EXPORT:-/home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929/export/pg_rot1_b4_T128}
LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
B=$D/bin/zk60_trained_block.gpu.release.bin
TAG=$1; Z=$2; shift 2
R=$D/stack-$TAG
mkdir -p "$R"
python3 $G run --class gpu --need-gib ${NEED:-4.5} --cap-gib ${CAP:-7} --label "gzc-stack-$TAG" --wait-secs 14400 --max-secs 1800 \
  --log "$R/prove.log" --done "$R/prove.done" --result-json "$R/prove.guard.json" \
  -- /usr/bin/env HL_PB_TIMING=1 HL_GPU=1 HL_GPU_REQUIRED=1 HL_GPU_ZEROCHECK=$Z RAYON_NUM_THREADS=16 LD_LIBRARY_PATH=$LD "$@" $B stack-prove --export "$E" --seq ho00 --out "$R/run"
echo "stack $TAG exit $?"
