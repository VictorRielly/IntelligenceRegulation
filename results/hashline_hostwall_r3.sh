#!/bin/bash
# [UPERF3 AJ] rung 3 measurement: the NARROW (int8/int16) upload, plus the
# chunk-size / NTT-thread sweep on top of rungs 1-2.
set -u
R=/home/victor/wt-uperf3-aj
CUDA_LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
GPU=$R/hashline/target-gpu/release/hashline
M8B=/home/victor/wt-uperf3-aa/results/m8b_mistral_v3_export
SP=$R/results/scratch_r3
mkdir -p $SP
say () { echo; echo "=== $* ==="; date '+%F %T'; }

say "GPU PROBE"
HL_GPU=1 LD_LIBRARY_PATH=$CUDA_LD $GPU gpu-probe 2>&1 | grep -E "gpu-probe:|ERROR|RED"

run () {
  local name=$1; shift
  say "ONE MISTRAL LAYER T=512, GPU — $name"
  env "$@" HL_GPU=1 HL_TIMING=1 HL_GPU_VERBOSE=1 LD_LIBRARY_PATH=$CUDA_LD \
    /usr/bin/time -v $GPU pass 1 512 --profile v3 --export $M8B --threads 8 \
    --proof-out $SP/l_$name.bin 2>&1 \
    | grep -vE "^\[UPERF3-XX\]   ntt rows" \
    | grep -E "streamed commit|chunked commit|re-encode|declined|WARNING|layer  0|PROVE|PROOF sha256|gpu device|Maximum resident|prover phases|^      "
  sha256sum $SP/l_$name.bin
  rm -f $SP/l_$name.bin
}

run r0base   HL_GPU_PIN_MB=0 HL_GPU_STREAM_COMMIT=0 HL_GPU_FUSE_GATHER=0 HL_GPU_NARROW=0
run c128t512_wide HL_GPU_CHUNK_ROWS=128 HL_GPU_NTT_THREADS=512 HL_GPU_NARROW=0
run c128t512 HL_GPU_CHUNK_ROWS=128 HL_GPU_NTT_THREADS=512
run c128t512b HL_GPU_CHUNK_ROWS=128 HL_GPU_NTT_THREADS=512
run c256t512 HL_GPU_CHUNK_ROWS=256 HL_GPU_NTT_THREADS=512
run c512t512 HL_GPU_CHUNK_ROWS=512 HL_GPU_NTT_THREADS=512
run c128t256 HL_GPU_CHUNK_ROWS=128 HL_GPU_NTT_THREADS=256
run c128t1024 HL_GPU_CHUNK_ROWS=128 HL_GPU_NTT_THREADS=1024
run c128t512nf HL_GPU_CHUNK_ROWS=128 HL_GPU_NTT_THREADS=512 HL_GPU_FUSE_GATHER=0
run c128t512p32 HL_GPU_CHUNK_ROWS=128 HL_GPU_NTT_THREADS=512 HL_GPU_PIN_MB=32
