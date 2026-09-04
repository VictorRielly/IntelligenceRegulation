#!/bin/bash
# [UPERF3 AJ] rungs 1+2 measurement: the pinned INTERLEAVED upload and the
# gather fused into the last NTT stage group. Four arms at one real
# Mistral-7B layer (T = 512) on the GPU; arm 1 must reproduce the lane's
# rung-0 baseline exactly (3.134 s, sha256 179ec2fb..).
set -u
R=/home/victor/wt-uperf3-aj
CUDA_LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
GPU=$R/hashline/target-gpu/release/hashline
M8B=/home/victor/wt-uperf3-aa/results/m8b_mistral_v3_export
SP=$R/results/scratch_r1
mkdir -p $SP
say () { echo; echo "=== $* ==="; date '+%F %T'; }

say "GPU PROBE (kernel correctness incl. the chunked commit + fused gather path)"
HL_GPU=1 LD_LIBRARY_PATH=$CUDA_LD $GPU gpu-probe 2>&1 | grep -E "gpu-probe:|chunked check|ERROR|RED"

run () {
  local name=$1; shift
  say "ONE MISTRAL LAYER T=512, GPU — $name"
  env "$@" HL_GPU=1 HL_TIMING=1 HL_GPU_VERBOSE=1 LD_LIBRARY_PATH=$CUDA_LD \
    /usr/bin/time -v $GPU pass 1 512 --profile v3 --export $M8B --threads 8 \
    --proof-out $SP/layer_$name.bin 2>&1 \
    | grep -vE "^\[UPERF3-XX\]   ntt rows" \
    | grep -E "chunked|streamed|layer  0|PROVE|PROOF sha256|gpu device|Maximum resident|Elapsed|prover phases|^      "
  sha256sum $SP/layer_$name.bin
  rm -f $SP/layer_$name.bin
}

run base   HL_GPU_PIN_MB=0 HL_GPU_STREAM_COMMIT=0 HL_GPU_FUSE_GATHER=0
run fuse   HL_GPU_PIN_MB=0 HL_GPU_STREAM_COMMIT=0
run stream HL_GPU_FUSE_GATHER=0
run both   HL_DUMMY=1
run both2  HL_DUMMY=1
# the chunk size is a free parameter: a 1024-row chunk's encoded scratch is
# 537 MB at the Mistral W shape (far beyond the 32 MB L2), a 128-row chunk
# is 67 MB. Multiples of 128 rows only (a blake3 chunk of a column).
run chunk256 HL_GPU_CHUNK_ROWS=256
run chunk128 HL_GPU_CHUNK_ROWS=128
run thr512   HL_GPU_NTT_THREADS=512
run thr1024  HL_GPU_NTT_THREADS=1024
run c128t512 HL_GPU_CHUNK_ROWS=128 HL_GPU_NTT_THREADS=512
