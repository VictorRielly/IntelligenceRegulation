#!/bin/bash
# [UPERF3-AI rung 3] THE HONEST DRAIN EXPERIMENT.
# A multi-layer Mistral-7B ZK pass on the GPU, run twice from ONE binary:
#   A: the per-layer VRAM pool drain ON  (default)
#   B: HL_ZK_DRAIN=0 — both drains off  (the pre-rung-3 behaviour)
# Everything else identical. What we are testing, all of it the dead agent's
# testimony and none of it evidence yet: (1) does layer 1+ fail or slow down
# without the drain, (2) is the drain value-neutral (same proof bytes).
set -u
R=/home/victor/wt-uperf3-ai
SP=$R/results/scratch-ai
MIS=/home/victor/wt-uperf3-aa/results/m8b_mistral_v3_export
GPU=$R/hashline/target-gpu/release/hashline
CUDA_LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
L=${1:-4}
mkdir -p "$SP"

run () { # run <tag> <HL_ZK_DRAIN value>
  local tag=$1 dr=$2
  echo; echo "=== RUN $tag (HL_ZK_DRAIN=$dr, $L layers x 512, Mistral-7B, GPU, ZK v3) ==="; date '+%F %T'
  nvidia-smi --query-gpu=memory.used --format=csv,noheader
  HL_GPU=1 HL_GPU_VERBOSE=1 HL_ZK_DRAIN=$dr LD_LIBRARY_PATH=$CUDA_LD \
    /usr/bin/time -v "$GPU" pass "$L" 512 --zk --seed 1 --profile v3 --export "$MIS" \
      --threads 8 --proof-out "$SP/zk8b_ab_$tag.bin" 2>&1 \
    | grep -Ev '^\s+(Average|Voluntary|Involuntary|Signals|Socket|Swaps|Page size|Minor|Major|File system|Exit status|Percent)'
  echo "--- exit: ${PIPESTATUS[0]} ---"
  if [ -f "$SP/zk8b_ab_$tag.bin" ]; then
    echo "PROOF $tag: $(sha256sum "$SP/zk8b_ab_$tag.bin" | cut -d' ' -f1)  $(stat -c %s "$SP/zk8b_ab_$tag.bin") B"
  else
    echo "PROOF $tag: NONE (run produced no proof)"
  fi
}

run drain 1
run nodrain 0

echo; echo "=== VALUE-NEUTRALITY (cmp of the two proofs) ==="
if [ -f "$SP/zk8b_ab_drain.bin" ] && [ -f "$SP/zk8b_ab_nodrain.bin" ]; then
  if cmp "$SP/zk8b_ab_drain.bin" "$SP/zk8b_ab_nodrain.bin"; then
    echo "IDENTICAL: the drain is value-neutral at $L Mistral layers"
  else
    echo "FAILURE: the two proofs DIFFER — the drain is NOT value-neutral"
  fi
else
  echo "cannot compare: one of the runs produced no proof"
fi
rm -f "$SP/zk8b_ab_drain.bin" "$SP/zk8b_ab_nodrain.bin"
date '+%F %T'
