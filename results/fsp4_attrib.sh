#!/bin/bash
# [FSP-HOST] The host-attribution run at the 12x512 fixture shape: the v3
# public fixture (the frozen `5f368db6240e0614..` gate) proved once on the
# GPU binary and once on the CPU binary with the EXISTING default-off
# instrumentation switched on:
#   HL_CONV_VERBOSE=1 -> layer.rs's per-layer conv/fold lines,
#   HL_TIMING=1       -> pcs::open's phase clocks per opening,
#   HL_FSP4_TIMING=1  -> this lane's upload split (probe / pack / dma),
#                        which does nothing on a tree that has not got it.
# Neither switch changes a proof byte; the digest is checked here too.
# Usage: fsp4_attrib.sh <scratch-dir> <tag>
set -u
R=/home/victor/wt-fsp-host
SP="${1:?scratch dir required}"
TAG="${2:?tag required}"
V3=/home/victor/wt-uperf3-aa/results/m8b_test/m125_v3_export
export M125_EXPORT_DIR=/home/victor/IntelligenceRegulation/results/m125_ffn_export_wsl
CUDA_LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
CPU=${FSP_CPU_BIN:-$R/hashline/target/release/hashline}
GPU=${FSP_GPU_BIN:-$R/hashline/target-gpu/release/hashline}
mkdir -p "$SP"
echo "=== box before ==="; date '+%F %T'; uptime; nvidia-smi --query-gpu=memory.used --format=csv,noheader
echo "=== GPU binary, v3 12x512 [$TAG] ==="
HL_GPU=1 LD_LIBRARY_PATH=$CUDA_LD HL_CONV_VERBOSE=1 HL_TIMING=1 HL_FSP4_TIMING=1 \
  "$GPU" pass 12 512 --threads 8 --profile v3 --export $V3 --proof-out "$SP/attrib-gpu.proof" 2>&1
sha256sum "$SP/attrib-gpu.proof" | cut -c1-16
stat -c %s "$SP/attrib-gpu.proof"
rm -f "$SP/attrib-gpu.proof"
echo "=== CPU binary, v3 12x512 [$TAG] ==="
HL_CONV_VERBOSE=1 HL_TIMING=1 HL_FSP4_TIMING=1 \
  "$CPU" pass 12 512 --threads 8 --profile v3 --export $V3 --proof-out "$SP/attrib-cpu.proof" 2>&1
sha256sum "$SP/attrib-cpu.proof" | cut -c1-16
stat -c %s "$SP/attrib-cpu.proof"
rm -f "$SP/attrib-cpu.proof"
echo "=== box after ==="; date '+%F %T'; uptime
echo "=== ATTRIB DONE ==="
