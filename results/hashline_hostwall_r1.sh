#!/bin/bash
# [UPERF3 AJ] rung 1 measurement: the pinned + interleaved upload.
# A/B at one real Mistral-7B layer (T = 512) on the GPU, then the four byte
# gates on both binaries.
set -u
R=/home/victor/wt-uperf3-aj
CUDA_LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
GPU=$R/hashline/target-gpu/release/hashline
M8B=/home/victor/wt-uperf3-aa/results/m8b_mistral_v3_export
SP=$R/results/scratch_r1
mkdir -p $SP
say () { echo; echo "=== $* ==="; date '+%F %T'; }

say "H2D BANDWIDTH PROBE"
HL_GPU=1 HL_GPU_BENCH_H2D=1 LD_LIBRARY_PATH=$CUDA_LD $GPU gpu-probe 2>&1 | grep -E "UPERF3-AJ|gpu-probe:"

for mode in off on; do
  say "ONE MISTRAL LAYER T=512, GPU, streamed upload $mode"
  if [ $mode = off ]; then
    ENV="HL_GPU_PIN_MB=0 HL_GPU_STREAM_COMMIT=0"
  else
    ENV=""
  fi
  env $ENV HL_GPU=1 HL_TIMING=1 HL_GPU_VERBOSE=1 LD_LIBRARY_PATH=$CUDA_LD \
    /usr/bin/time -v $GPU pass 1 512 --profile v3 --export $M8B --threads 8 \
    --proof-out $SP/layer_$mode.bin 2>&1 \
    | grep -vE "^\[UPERF3-XX\]   ntt rows" \
    | grep -E "commit|chunked|zero-check|pcs::open|layer  0|PROVE|PROOF sha256|gpu device|Maximum resident|Elapsed|prover phases|^      "
  sha256sum $SP/layer_$mode.bin
done
