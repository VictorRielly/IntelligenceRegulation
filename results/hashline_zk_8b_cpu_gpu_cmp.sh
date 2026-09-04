#!/bin/bash
# [UPERF3-AI rung 3] THE BYTE-IDENTITY OF THE MULTI-LAYER MISTRAL ZK PROOF, CPU vs GPU.
# Rung 1 proved ONE Mistral layer identical (b5da6c38..). This extends it to a CHAINED
# multi-layer pass, where each layer's transcript continues the previous one's.
# 4 layers, not 32: the CPU ZK prover peaks near 13 GB RSS on a 15 GB box shared with two
# other lanes, and a 32-layer CPU ZK pass is ~11 minutes of prove at that peak — out of
# reach here without risking the box for the other agents.
set -u
R=/home/victor/wt-uperf3-ai
SP=$R/results/scratch-ai
MIS=/home/victor/wt-uperf3-aa/results/m8b_mistral_v3_export
CPU=$R/hashline/target/release/hashline
GPU=$R/hashline/target-gpu/release/hashline
CUDA_LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
L=4
mkdir -p "$SP"

echo "=== GPU: pass $L 512 --zk --seed 1 --profile v3 (Mistral-7B) ==="; date '+%F %T'
HL_GPU=1 LD_LIBRARY_PATH=$CUDA_LD /usr/bin/time -v "$GPU" pass $L 512 --zk --seed 1 \
  --profile v3 --export "$MIS" --threads 8 --proof-out "$SP/cmp_gpu.bin" 2>&1 \
  | grep -Ei 'PROVE|VERIFY|PROOF sha256|ACCEPT|REJECT|Maximum resident|error|panic|layer +[0-9]+:|vram'

echo; echo "=== CPU: the same statement, no GPU ==="; date '+%F %T'
/usr/bin/time -v "$CPU" pass $L 512 --zk --seed 1 --profile v3 --export "$MIS" \
  --threads 8 --proof-out "$SP/cmp_cpu.bin" 2>&1 \
  | grep -Ei 'PROVE|VERIFY|PROOF sha256|ACCEPT|REJECT|Maximum resident|error|panic|layer +[0-9]+:'

echo; echo "=== VERDICT ==="; date '+%F %T'
sha256sum "$SP/cmp_gpu.bin" "$SP/cmp_cpu.bin"
stat -c '%n %s B' "$SP/cmp_gpu.bin" "$SP/cmp_cpu.bin"
if cmp "$SP/cmp_gpu.bin" "$SP/cmp_cpu.bin"; then
  echo "BYTE-IDENTICAL: the $L-layer chained Mistral ZK proof is the same on CPU and GPU"
else
  echo "FAILURE: the CPU and GPU proofs DIFFER"
fi
rm -f "$SP/cmp_gpu.bin" "$SP/cmp_cpu.bin"
