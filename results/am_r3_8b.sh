#!/bin/bash
# [UPERF3 lane AM rung 3] THE TWO 8B ROWS, BOTH TIERS, ONE SESSION, ONE BINARY.
#   FAST TIER  P1: private inputs + activations + output, PUBLIC weights, the
#                  per-model weight cache allowed (cold here: 32 misses).
#                  Must reproduce 930ce9a043a03721.. / 1,285,578,368 B.
#   FULL TIER  P3: the weights private too — committed hidingly and re-committed
#                  with fresh randomness on this proof; --wcache refused.
# Mistral-7B, 32 layers x 512 tokens, GPU, detached under the heavy lock.
set -u
R=/home/victor/wt-uperf3-am
MI=/home/victor/wt-uperf3-aa/results/m8b_mistral_v3_export
export M125_EXPORT_DIR=/home/victor/IntelligenceRegulation/results/m125_ffn_export_wsl
CUDA_LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
GPU=$R/hashline/target-gpu/release/hashline
SP=$R/results/am_scratch
WC=$SP/wcache-8b
mkdir -p "$SP"
rm -rf "$WC"; mkdir -p "$WC"
say () { echo; echo "=== $* ==="; date '+%F %T'; free -g | head -2; }

say "FAST TIER (P1) — 8B GPU, 32 x 512, cold weight cache"
HL_GPU=1 LD_LIBRARY_PATH=$CUDA_LD /usr/bin/time -v $GPU pass 32 512 --threads 8 --zk --seed 1 \
  --profile v3 --export $MI --wcache $WC --proof-out $SP/8b-p1.proof 2>&1 \
  | grep -Ev '^      (g8|rg|a16|u16|ru|h16|rh|table slot|A masks|H masks|layout)'
say "P1 digest"
sha256sum $SP/8b-p1.proof; stat -c '%s B' $SP/8b-p1.proof
rm -f $SP/8b-p1.proof
rm -rf "$WC"

say "FULL TIER (P3) — 8B GPU, 32 x 512, no cache (refused by the mode)"
HL_GPU=1 LD_LIBRARY_PATH=$CUDA_LD /usr/bin/time -v $GPU pass 32 512 --threads 8 --p3 --seed 1 \
  --profile v3 --export $MI --proof-out $SP/8b-p3.proof 2>&1 \
  | grep -Ev '^      (g8|rg|a16|u16|ru|h16|rh|table slot|A masks|H masks|layout)'
say "P3 digest"
sha256sum $SP/8b-p3.proof; stat -c '%s B' $SP/8b-p3.proof

say "the clear-value scan of the 8B P3 proof"
python3 $R/results/am_r0_output_scan.py $SP/8b-p3.proof
rm -f $SP/8b-p3.proof

say "DONE"
