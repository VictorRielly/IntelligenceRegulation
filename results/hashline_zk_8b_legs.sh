#!/bin/bash
# [UPERF3-AI rung 3] The eight v3 tamper legs at MISTRAL-7B width, through the GPU ZK
# prover, on the final rung-3 binary. Rung 2 established them (8/8 REJECT) before the
# VRAM discipline landed; this re-establishes them after it.
set -u
R=/home/victor/wt-uperf3-ai
MIS=/home/victor/wt-uperf3-aa/results/m8b_mistral_v3_export
GPU=$R/hashline/target-gpu/release/hashline
CUDA_LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
date '+%F %T'
HL_GPU=1 LD_LIBRARY_PATH=$CUDA_LD "$GPU" layer 0 512 --zk --seed 1 --profile v3 \
  --export "$MIS" --threads 8 --all-tampers 2>&1
echo "--- exit: $? ---"
date '+%F %T'
