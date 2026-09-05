#!/bin/bash
# [ZK60-CL5] The profile matrix at SAFE 125M shapes.
#
# Small repeated diagnostic runs, under the shared heavy lock, on the 8 GB
# laptop. NOT a headline benchmark: the box is not quiesced-certified and no
# p95 is produced here. Each configuration runs REPS times so run-to-run
# spread is visible rather than assumed away.
#
# Covers the axes CL5 asks to separate: P0 (no ZK) / P1 (public W, hiding
# activations) / P3 (private W), and a COLD vs WARM public weight cache.
set -u
R=/home/victor/wt-zk60-cl1
SP="${1:?scratchpad dir required}"
REPS="${2:-3}"
V3=/home/victor/wt-uperf3-aa/results/m8b_test/m125_v3_export
export M125_EXPORT_DIR=/home/victor/IntelligenceRegulation/results/m125_ffn_export_wsl
CUDA_LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
GPU=$R/hashline/target-gpu/release/hashline
mkdir -p "$SP"

say () { echo; echo "=== $* ==="; date '+%F %T'; }
run () {   # run <tag> <extra args...>
  local tag=$1; shift
  for i in $(seq 1 "$REPS"); do
    local log=$SP/$tag.$i.log
    say "$tag rep $i"
    nvidia-smi --query-gpu=memory.used --format=csv,noheader
    HL_GPU=1 LD_LIBRARY_PATH=$CUDA_LD "$GPU" pass 12 512 --threads 8 \
      --profile v3 --export $V3 --proof-out "$SP/$tag.proof" "$@" > "$log" 2>&1
    local rc=$?
    echo "exit $rc" | tee -a "$log"
    grep -E 'gpu: |PASS.*(ACCEPT|REJECT)|HASHLINE_TIMING' "$log" | head -3
    rm -f "$SP/$tag.proof"
  done
}

say "P0 — no ZK, public everything"
run p0

say "P1 — hiding activations, PUBLIC weights, COLD weight cache"
WC=$SP/wcache-cold
for i in $(seq 1 "$REPS"); do
  rm -rf "$WC"; mkdir -p "$WC"
  log=$SP/p1cold.$i.log
  say "p1cold rep $i"
  HL_GPU=1 LD_LIBRARY_PATH=$CUDA_LD "$GPU" pass 12 512 --threads 8 --zk --seed 1 \
    --profile v3 --export $V3 --wcache "$WC" --proof-out "$SP/p1cold.proof" > "$log" 2>&1
  echo "exit $?" | tee -a "$log"
  grep -E 'gpu: |PASS.*(ACCEPT|REJECT)' "$log" | head -2
  rm -f "$SP/p1cold.proof"
done

say "P1 — WARM weight cache (same directory reused)"
for i in $(seq 1 "$REPS"); do
  log=$SP/p1warm.$i.log
  say "p1warm rep $i"
  HL_GPU=1 LD_LIBRARY_PATH=$CUDA_LD "$GPU" pass 12 512 --threads 8 --zk --seed 1 \
    --profile v3 --export $V3 --wcache "$WC" --proof-out "$SP/p1warm.proof" > "$log" 2>&1
  echo "exit $?" | tee -a "$log"
  grep -E 'gpu: |PASS.*(ACCEPT|REJECT)' "$log" | head -2
  rm -f "$SP/p1warm.proof"
done

say "P3 — PRIVATE weights, cache refused by the mode"
run p3 --p3 --seed 1

say "P1 — no cache directory (the byte-gate configuration)"
run p1nocache --zk --seed 1

say "DONE"
