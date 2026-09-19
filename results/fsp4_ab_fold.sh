#!/bin/bash
# [FSP-HOST] The A/B of the int8 block fold at the 12x512 fixture shape,
# ONE binary, two arms, alternating A-B-B-A-A-B-B-A-A-B (5 each):
#   A = HL_FSP4_I128FOLD=0  (the inherited fold: Fp2::mul_base per element)
#   B = default             (this lane's deferred i128 accumulation)
# Every process prints layer.rs's HL_CONV_VERBOSE fold lines and the
# PASS-V3 line, so the A/B has both the ITEM's seconds and the prove's.
# The proof is written and its digest printed in every run: a moved digest
# is a bug, not a result.
# Usage: fsp4_ab_fold.sh <scratch-dir> <cpu|gpu> <n-per-arm>
set -u
R=/home/victor/wt-fsp-host
SP="${1:?scratch dir required}"
WHICH="${2:?cpu or gpu}"
N="${3:-5}"
V3=/home/victor/wt-uperf3-aa/results/m8b_test/m125_v3_export
export M125_EXPORT_DIR=/home/victor/IntelligenceRegulation/results/m125_ffn_export_wsl
CUDA_LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
CPU=${FSP_CPU_BIN:-$R/hashline/target/release/hashline}
GPU=${FSP_GPU_BIN:-$R/hashline/target-gpu/release/hashline}
mkdir -p "$SP"
echo "=== box before ==="; date '+%F %T'; uptime; nvidia-smi --query-gpu=memory.used --format=csv,noheader
run () {
  local arm=$1 i=$2
  local out=$SP/ab-$WHICH-$arm-$i.proof
  echo "--- ARM $arm run $i [$WHICH] ---"; date '+%F %T'
  if [ "$WHICH" = gpu ]; then
    HL_GPU=1 LD_LIBRARY_PATH=$CUDA_LD HL_CONV_VERBOSE=1 HL_FSP4_I128FOLD=$arm \
      "$GPU" pass 12 512 --threads 8 --profile v3 --export $V3 --proof-out "$out" 2>&1 \
      | grep -E 'fold gu|fold d |PASS-V3|PROVE|error|panic'
  else
    HL_CONV_VERBOSE=1 HL_FSP4_I128FOLD=$arm \
      "$CPU" pass 12 512 --threads 8 --profile v3 --export $V3 --proof-out "$out" 2>&1 \
      | grep -E 'fold gu|fold d |PASS-V3|PROVE|error|panic'
  fi
  echo "DIGEST $(sha256sum "$out" | cut -c1-16) $(stat -c %s "$out") B"
  rm -f "$out"
}
i=1
while [ $i -le "$N" ]; do
  if [ $((i % 2)) = 1 ]; then run 0 $i; run 1 $i; else run 1 $i; run 0 $i; fi
  i=$((i + 1))
done
echo "=== box after ==="; date '+%F %T'; uptime
echo "=== AB DONE ==="
