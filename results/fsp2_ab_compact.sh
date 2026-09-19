#!/bin/bash
# [FSP-L9] The A/B for the two changes this lane KEEPS, separated.
#
#   arm A  = the saved pre-change binary  -> serial host split, no compact pair
#   arm B  = this lane's binary, HL_GPU_P1_COMPACT=0
#                                        -> parallel host split, no compact pair
#   arm C  = this lane's binary, HL_GPU_P1_COMPACT=1
#                                        -> parallel host split + compact pair
#
# B - A isolates the host tail of `columns_chunked` (a CROSS-BINARY
# comparison: the only source difference on that path is the split itself
# and two OnceLock switch reads). C - B isolates the compact
# producer/consumer pair, in one binary, switch-only. Order A B C C B A so
# any drift in the box cancels. The per-kernel A/B printed inside every
# process is switch-independent (the bench launches each kernel by name),
# so arms B and C also reprint the kernel table.
# Usage: fsp2_ab_compact.sh <log-file> [rows]
set -u
R=/home/victor/wt-fsp-l9
LOG="${1:?log file required}"
ROWS="${2:-10752}"
CUDA_LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
NEW=$R/hashline/target-gpu/release/hashline
BASE=/tmp/claude-1000/-home-victor-IntelligenceRegulation/e277dbc7-36bc-4ae1-8184-db91a6d569e4/scratchpad/fspl9/hashline-base-gpu

arm () {
  local label=$1 bin=$2 compact=$3
  echo "=== ARM $label (bin $(basename "$bin"), HL_GPU_P1_COMPACT=$compact) ===" >> "$LOG"
  date '+%F %T' >> "$LOG"
  nvidia-smi --query-gpu=memory.used --format=csv,noheader >> "$LOG"
  HL_GPU=1 HL_GPU_BENCH_REENC=1 HL_BENCH_ROWS=$ROWS HL_BENCH_REPS=7 \
    HL_GPU_P1_COMPACT=$compact \
    LD_LIBRARY_PATH=$CUDA_LD "$bin" gpu-probe 2>&1 \
    | grep -E 'UPERF3-AO|FSP-L9|gpu-probe:|GeForce' >> "$LOG"
}

arm A "$BASE" 0
arm B "$NEW"  0
arm C "$NEW"  1
arm C "$NEW"  1
arm B "$NEW"  0
arm A "$BASE" 0
echo "=== A/B DONE ===" >> "$LOG"
