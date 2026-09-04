#!/bin/bash
# [UPERF3 lane AM rung 1] MODE P3 at the 125M v3 shape: the CPU/GPU byte parity
# of the new statement, the tamper legs through the GPU prover, and the P1-vs-P3
# cost at the same shape on the same binaries in the same session.
set -u
R=/home/victor/wt-uperf3-am
V3=/home/victor/wt-uperf3-aa/results/m8b_test/m125_v3_export
export M125_EXPORT_DIR=/home/victor/IntelligenceRegulation/results/m125_ffn_export_wsl
CUDA_LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
CPU=$R/hashline/target/release/hashline
GPU=$R/hashline/target-gpu/release/hashline
SP=$R/results/am_scratch
mkdir -p "$SP"

say () { echo; echo "=== $* ==="; date '+%F %T'; }

say "P3 12x512 CPU"
$CPU pass 12 512 --threads 8 --p3 --seed 1 --profile v3 --export $V3 --proof-out $SP/p3-cpu.proof 2>&1 \
  | grep -Ei 'MODE|PROVE|VERIFY|PROOF sha256|ACCEPT|REJECT|W group|W prox|W masks|W:|error|panic'

say "P3 12x512 GPU"
HL_GPU=1 LD_LIBRARY_PATH=$CUDA_LD $GPU pass 12 512 --threads 8 --p3 --seed 1 --profile v3 --export $V3 --proof-out $SP/p3-gpu.proof 2>&1 \
  | grep -Ei 'MODE|PROVE|VERIFY|PROOF sha256|ACCEPT|REJECT|vram|gpu device-side|error|panic'

say "P3 CPU == GPU?"
cmp $SP/p3-cpu.proof $SP/p3-gpu.proof && echo "BYTE-IDENTICAL" || echo "FAILURE: P3 CPU and GPU proofs differ"
sha256sum $SP/p3-cpu.proof $SP/p3-gpu.proof
stat -c '%n %s B' $SP/p3-cpu.proof

say "P1 12x512 CPU and GPU, same binaries, same session (the cost comparison)"
$CPU pass 12 512 --threads 8 --zk --seed 1 --profile v3 --export $V3 2>&1 | grep -Ei 'PROVE|PROOF sha256|ACCEPT'
HL_GPU=1 LD_LIBRARY_PATH=$CUDA_LD $GPU pass 12 512 --threads 8 --zk --seed 1 --profile v3 --export $V3 2>&1 | grep -Ei 'PROVE|PROOF sha256|ACCEPT'

say "P3 tamper legs through the GPU prover (layer 0, T=16) + the pass-level leg"
HL_GPU=1 LD_LIBRARY_PATH=$CUDA_LD $GPU layer 0 16 --p3 --seed 1 --profile v3 --export $V3 --all-tampers 2>&1 \
  | grep -Ei 'tamper|GREEN|RED|error|panic'
HL_GPU=1 LD_LIBRARY_PATH=$CUDA_LD $GPU pass 2 64 --p3 --seed 1 --profile v3 --export $V3 --tamper z 2>&1 | grep -Ei 'REJECT|ACCEPT'

say "the clear-value scan of the P3 12x512 proof (rung 1's acceptance test)"
python3 $R/results/am_r0_output_scan.py $SP/p3-cpu.proof

say "DONE"
