#!/bin/bash
# [UPERF3 AO] Lever L9's END-TO-END A/B: `columns_chunked` — the function
# the PCS opening actually calls — with the lane's two kernel changes off
# and on, at the 8B pass's PCS shape and its exact W row count (10,752
# rows of 2^14, RS-encoded to 2^16, 256 opened columns, chunk 128 rows).
# ~1.5 GB of VRAM: this is NOT the 8B pass, which this 8 GB card cannot
# hold. The switches are read once per process (OnceLock), so each arm is
# its own process; the order is A-B-B-A so that any drift in the box
# cancels. Usage: ao_ab_reenc.sh <log-file>
set -u
R=/home/victor/wt-uperf3-ao
LOG="${1:?log file required}"
CUDA_LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
GPU=$R/hashline/target-gpu/release/hashline

arm () {
  local label=$1 fast=$2 skip=$3
  echo "=== ARM $label (HL_GPU_NTT_FAST=$fast HL_GPU_PAD_SKIP=$skip) ===" >> "$LOG"
  nvidia-smi --query-gpu=memory.used --format=csv,noheader >> "$LOG"
  HL_GPU=1 HL_GPU_BENCH_REENC=1 HL_BENCH_ROWS=10752 HL_BENCH_REPS=7 \
    HL_GPU_NTT_FAST=$fast HL_GPU_PAD_SKIP=$skip \
    LD_LIBRARY_PATH=$CUDA_LD "$GPU" gpu-probe 2>&1 \
    | grep -E 'UPERF3-AO|gpu-probe:|GeForce' >> "$LOG"
}

arm base 0 0
arm lane 1 1
arm lane 1 1
arm base 0 0
echo "=== A/B DONE ===" >> "$LOG"
