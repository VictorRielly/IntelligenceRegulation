#!/bin/bash
# [UPERF3 AJ] rung 4: the four byte gates (standard + forced-chunked) on both
# binaries, then the 32-layer 8B GPU pass BEFORE and AFTER this lane, in one
# session on one box.
set -u
R=/home/victor/wt-uperf3-aj
CUDA_LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
GPU=$R/hashline/target-gpu/release/hashline
M8B=/home/victor/wt-uperf3-aa/results/m8b_mistral_v3_export
SP=$R/results/scratch_r4
mkdir -p $SP
say () { echo; echo "=== $* ==="; date '+%F %T'; }

$R/results/hashline_hostwall_floors.sh $SP || { echo "FAILURE: gates RED — the 8B passes are NOT run"; exit 1; }

pass8b () {
  local name=$1; shift
  say "8B PASS 32x512 GPU — $name"
  rm -rf $SP/wc_$name; mkdir -p $SP/wc_$name
  env "$@" HL_GPU=1 HL_GPU_VERBOSE=1 LD_LIBRARY_PATH=$CUDA_LD \
    /usr/bin/time -v $GPU pass 32 512 --profile v3 --export $M8B --threads 8 \
    --wcache $SP/wc_$name --proof-out $SP/p_$name.bin 2>&1 \
    | grep -vE "^\[UPERF3-(XX|AC|AJ)\]   " \
    | grep -E "PASS-V3|PROVE|PROOF sha256|gpu device|gpu chunked|prover phases|^      |Maximum resident|Elapsed|wcache|declined|WARNING"
  sha256sum $SP/p_$name.bin
  ls -l $SP/p_$name.bin
  rm -f $SP/p_$name.bin
  rm -rf $SP/wc_$name
}

layer1 () {
  local name=$1; shift
  say "ONE MISTRAL LAYER T=512 GPU — $name"
  env "$@" HL_GPU=1 HL_GPU_VERBOSE=1 LD_LIBRARY_PATH=$CUDA_LD $GPU pass 1 512 --profile v3 \
    --export $M8B --threads 8 --proof-out $SP/l.bin 2>&1 \
    | grep -E "streamed commit rows 10752|PASS-V3|PROOF sha256|declined|WARNING"
  sha256sum $SP/l.bin; rm -f $SP/l.bin
}
for i in 1 2 3; do
  layer1 r0base HL_GPU_PIN_MB=0 HL_GPU_STREAM_COMMIT=0 HL_GPU_FUSE_GATHER=0 HL_GPU_NARROW=0 HL_GPU_CHUNK_ROWS=1024 HL_GPU_NTT_THREADS=256
  layer1 after HL_DUMMY=1
  layer1 after_wide HL_GPU_NARROW=0
done

pass8b before HL_GPU_PIN_MB=0 HL_GPU_STREAM_COMMIT=0 HL_GPU_FUSE_GATHER=0 HL_GPU_NARROW=0 HL_GPU_CHUNK_ROWS=1024 HL_GPU_NTT_THREADS=256
pass8b after  HL_DUMMY=1
