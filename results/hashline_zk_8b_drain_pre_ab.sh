#!/bin/bash
# [UPERF3-AI rung 3] THE THIRD DRAIN, A/B'd in one binary.
# The 4-layer trace showed WHY layers 1..31 cost 8.3 s where layer 0 costs 4.4 s: at layer 0
# the zero-check table reservation FAILS, dev_reserve_hard drains the pool and retries, and the
# layer runs with real VRAM; at every later layer the same reservation SUCCEEDS with 494 MiB
# free, because WSL backs cuMemAlloc with host memory rather than failing — so the tables are
# PAGED and the whole helpers/H/zero-check phase runs against host memory.
# HL_ZK_DRAIN_PRE=1 (default) drains the pool just before that reservation; =0 is the old
# behaviour. Same binary, same statement, back to back, and the proofs must be identical.
set -u
R=/home/victor/wt-uperf3-ai
SP=$R/results/scratch-ai
MIS=/home/victor/wt-uperf3-aa/results/m8b_mistral_v3_export
GPU=$R/hashline/target-gpu/release/hashline
CUDA_LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
L=${1:-4}
mkdir -p "$SP"

run () { # run <tag> <HL_ZK_DRAIN_PRE>
  local tag=$1 pre=$2
  echo; echo "=== RUN $tag (HL_ZK_DRAIN_PRE=$pre, $L Mistral layers x 512, GPU, ZK v3) ==="; date '+%F %T'
  HL_GPU=1 HL_GPU_VERBOSE=1 HL_ZK_DRAIN_PRE=$pre LD_LIBRARY_PATH=$CUDA_LD \
    /usr/bin/time -v "$GPU" pass "$L" 512 --zk --seed 1 --profile v3 --export "$MIS" \
      --threads 8 --proof-out "$SP/pre_$tag.bin" 2>&1 \
    | grep -Ei 'vram|drain|layer +[0-9]+:|zero-check kind|PROVE|PASS-V3|PROOF sha256|Maximum resident|panic|OUT_OF_MEMORY|declined|unaffordable'
  echo "--- exit: ${PIPESTATUS[0]} ---"
  [ -f "$SP/pre_$tag.bin" ] && echo "PROOF $tag: $(sha256sum "$SP/pre_$tag.bin" | cut -d' ' -f1)  $(stat -c %s "$SP/pre_$tag.bin") B"
}

run on 1
run off 0

echo; echo "=== VALUE-NEUTRALITY ==="
if [ -f "$SP/pre_on.bin" ] && [ -f "$SP/pre_off.bin" ]; then
  cmp "$SP/pre_on.bin" "$SP/pre_off.bin" && echo "IDENTICAL: the third drain changes no bytes" \
    || echo "FAILURE: the two proofs DIFFER"
else
  echo "cannot compare: a run produced no proof"
fi
echo "(the reference from the pre-site-3 binary at 4 layers: 9f2f35a383295118.. / 160,708,048 B / PROVE 31.15 s)"
rm -f "$SP/pre_on.bin" "$SP/pre_off.bin"
date '+%F %T'
