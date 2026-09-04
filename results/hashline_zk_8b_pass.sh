#!/bin/bash
# [UPERF3-AI rung 3] THE DELIVERABLE: the 32-layer Mistral-7B (8B) pass at T=512
# in ZERO KNOWLEDGE (mode P1: private inputs and activations, public weights) ON
# THE GPU. Lane AH's non-ZK row for the same statement is 95.48 s prove /
# 1,234,936,956 B / dc980e81..; lane AD's measured P1 surcharge on one Mistral
# layer is +4.7% prover, +3.9% bytes, so this row is expected near 100 s.
# Configuration is AH's rung 4 exactly (cold wcache dir), plus --zk --seed 1.
set -u
R=/home/victor/wt-uperf3-ai
SP=$R/results/scratch-ai
MIS=/home/victor/wt-uperf3-aa/results/m8b_mistral_v3_export
BIN=${BIN:-$R/hashline/target-gpu/release/hashline}
CUDA_LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
TAG=${TAG:-gpu}
OUT=$SP/zk8b_$TAG.bin
WC=$SP/wc8b_$TAG
mkdir -p "$SP"; rm -rf "$WC"; mkdir -p "$WC"; rm -f "$OUT"

echo "=== 8B ZK PASS [$TAG]: 32 x 512, Mistral-7B, --zk --seed 1 --profile v3 ==="
date '+%F %T'; uptime; nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader
echo "binary: $BIN"; ls -la "$BIN"

if [ "$TAG" = gpu ]; then export HL_GPU=1; fi
LD_LIBRARY_PATH=$CUDA_LD /usr/bin/time -v "$BIN" pass 32 512 --zk --seed 1 --profile v3 \
  --export "$MIS" --wcache "$WC" --threads 8 --proof-out "$OUT" 2>&1
echo "--- exit: $? ---"
date '+%F %T'
echo "=== THE DIGEST, TAKEN BY HAND OVER THE WRITTEN FILE ==="
sha256sum "$OUT"
stat -c '%n %s B' "$OUT"
du -sh "$WC"; echo "wcache files: $(ls "$WC" | wc -l)"
nvidia-smi --query-gpu=memory.used --format=csv,noheader
