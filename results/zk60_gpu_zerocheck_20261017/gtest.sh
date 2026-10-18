#!/bin/bash
# GPU ZERO-CHECK lane: ONE guarded `cargo test` (build + run) of the lane copy
# with the gpu-cuda feature, class gpu (HL_GPU=1), never chained with another
# GPU pass. usage: gtest.sh <label> debug|release <need> <cap> <max-secs> <filter> [extra env ...] -- [test args]
set -u
L=$1; P=$2; NEED=$3; CAP=$4; MAX=$5; F=$6; shift 6
XENV=()
while [ $# -gt 0 ] && [ "$1" != "--" ]; do XENV+=("$1"); shift; done
[ $# -gt 0 ] && shift
E=/home/victor/IntelligenceRegulation/results/zk60_gpu_zerocheck_20261017/logs
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
W=/home/victor/IntelligenceRegulation/ops/zkp-mvp/gpu-zerocheck/hashline
LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
REL=""; [ "$P" = release ] && REL="--release"
python3 $G run --class gpu --need-gib "$NEED" --cap-gib "$CAP" --label "$L" --wait-secs 14400 --max-secs "$MAX" \
  --log "$E/$L.log" --done "$E/$L.done" --result-json "$E/$L.guard.json" \
  -- /usr/bin/env CUDA_ROOT=/home/victor/cuda-root LD_LIBRARY_PATH=$LD CARGO_TARGET_DIR=$W/target-gpu HL_GPU=1 RAYON_NUM_THREADS=16 HL_GZC_CACHE_DIR=/home/victor/IntelligenceRegulation/results/zk60_gpu_zerocheck_20261017/gzc_module_cache "${XENV[@]}" \
     /home/victor/.cargo/bin/cargo test $REL --offline --locked -j2 --manifest-path $W/Cargo.toml --features gpu-cuda --lib "$F" -- --test-threads=1 --nocapture "$@"
