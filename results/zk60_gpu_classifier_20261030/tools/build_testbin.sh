#!/bin/bash
# GPU CLASSIFIER lane: ONE guarded release build of the lane tree's lib test binary with --features gpu-cuda (no run).
set -u
L=$1
D=/home/victor/IntelligenceRegulation/results/zk60_gpu_classifier_20261030
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
W=/home/victor/IntelligenceRegulation/ops/zkp-mvp/gpu-classifier/hashline
LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
while [ -e "$D/HOLD" ]; do sleep 30; done
python3 $G run --class build --need-gib 2.5 --cap-gib 5 --label "gcl-$L" --wait-secs 7200 --max-secs 2400 \
  --log "$D/logs/$L.log" --done "$D/logs/$L.guard.done" --result-json "$D/logs/$L.guard.json" \
  -- /usr/bin/env CUDA_ROOT=/home/victor/cuda-root LD_LIBRARY_PATH=$LD CARGO_TARGET_DIR=$W/target-gpu /home/victor/.cargo/bin/cargo test --release --offline --locked -j2 --manifest-path $W/Cargo.toml --features gpu-cuda --lib --no-run
