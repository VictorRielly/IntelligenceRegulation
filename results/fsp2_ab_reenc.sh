#!/bin/bash
# [FSP-L9] The END-TO-END A/B on `columns_chunked` — the function the PCS
# opening actually calls — with this lane's two swizzled-shared-layout
# kernels off and on, at the 8B pass's PCS shape and its exact W row count
# (10,752 rows of 2^14, RS-encoded to 2^16, 256 opened columns, chunk 128
# rows). ~1.5 GB of VRAM: this is NOT the 8B pass. Lane AO's three
# switches stay ON in both arms, so the base arm is the current tip.
# The switches are read once per process (OnceLock), so each arm is its own
# process; the order is A-B-B-A so any drift in the box cancels.
# The per-kernel A/B inside each process is independent of the switches
# (the bench launches every kernel by name), so each process also reprints
# the kernel table.
# Usage: fsp2_ab_reenc.sh <log-file> [rows]
set -u
R=/home/victor/wt-fsp-l9
LOG="${1:?log file required}"
ROWS="${2:-10752}"
CUDA_LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
GPU=$R/hashline/target-gpu/release/hashline

arm () {
  local label=$1 v=$2
  echo "=== ARM $label (HL_GPU_SMEM_SWZ/_PB = $v) ===" >> "$LOG"
  date '+%F %T' >> "$LOG"
  nvidia-smi --query-gpu=memory.used --format=csv,noheader >> "$LOG"
  HL_GPU=1 HL_GPU_BENCH_REENC=1 HL_BENCH_ROWS=$ROWS HL_BENCH_REPS=7 \
    HL_GPU_SMEM_SWZ=$v HL_GPU_SMEM_SWZ_PB=$v \
    LD_LIBRARY_PATH=$CUDA_LD "$GPU" gpu-probe 2>&1 \
    | grep -E 'UPERF3-AO|FSP-L9|gpu-probe:|GeForce' >> "$LOG"
}

arm base 0
arm lane 1
arm lane 1
arm base 0
echo "=== A/B DONE ===" >> "$LOG"
