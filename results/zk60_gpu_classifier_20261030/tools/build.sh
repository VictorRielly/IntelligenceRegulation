#!/bin/bash
# GPU CLASSIFIER lane (D53, 2026-10-30): ONE guarded release build of the classifier CLI from the lane tree.
# usage: build.sh <label> cpu|gpu      (cpu: the crate defaults; gpu: --features gpu-cuda, own target dir)
set -u
L=$1; M=$2
D=/home/victor/IntelligenceRegulation/results/zk60_gpu_classifier_20261030
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
W=/home/victor/IntelligenceRegulation/ops/zkp-mvp/gpu-classifier/hashline
LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
C=/home/victor/.cargo/bin/cargo
while [ -e "$D/HOLD" ]; do sleep 30; done
case "$M" in
  cpu) ENVS="CARGO_TARGET_DIR=$W/target"; FEAT="" ;;
  gpu) ENVS="CUDA_ROOT=/home/victor/cuda-root LD_LIBRARY_PATH=$LD CARGO_TARGET_DIR=$W/target-gpu"; FEAT="--features gpu-cuda" ;;
  *) echo "bad mode"; exit 2 ;;
esac
python3 $G run --class build --need-gib 2.5 --cap-gib 5 --label "gcl-$L" --wait-secs 7200 --max-secs 2400 \
  --log "$D/logs/$L.log" --done "$D/logs/$L.guard.done" --result-json "$D/logs/$L.guard.json" \
  -- /usr/bin/env $ENVS $C build --release --offline --locked -j2 --manifest-path $W/Cargo.toml $FEAT --example zk60_classify
