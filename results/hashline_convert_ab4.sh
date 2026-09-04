#!/bin/bash
# [UPERF3 AL] The 4-layer Mistral A/B: one binary, one session, the lane's
# switches ON and OFF. 4 layers is the smallest run that shows the staging
# pool (layer 0 always pays the first allocation; layers 1..3 do not).
set -u
R=/home/victor/wt-uperf3-al
CUDA_LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
GPU=$R/hashline/target-gpu/release/hashline
M8B=/home/victor/wt-uperf3-aa/results/m8b_mistral_v3_export
SP=$R/results/scratch_al
N=${N:-4}
mkdir -p $SP
arm () {
  local name=$1; shift
  echo; echo "=== ${N}-LAYER MISTRAL T=512 GPU — $name ==="; date '+%F %T'
  env "$@" HL_GPU=1 HL_GPU_VERBOSE=1 HL_CONV_VERBOSE=1 LD_LIBRARY_PATH=$CUDA_LD \
    $GPU pass $N 512 --profile v3 --export $M8B --threads 8 --proof-out $SP/ab.bin 2>&1 \
    | grep -E "UPERF3-AL|PASS-V3|PROOF sha256|prover phases|^      |declined|WARNING"
  sha256sum $SP/ab.bin
  rm -f $SP/ab.bin
}
for i in 1 2; do
  arm before HL_AL_POOL=0 HL_AL_I8FOLD=0
  arm after  HL_DUMMY=1
done
