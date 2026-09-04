#!/bin/bash
# [UPERF3 lane AM rung 2] MODE P3 at MISTRAL WIDTH (d 4096, f 14336): the tamper
# legs, and the P1-vs-P3 cost on ONE layer at T=512 with peak RSS/VRAM — the
# reconnaissance for the 32-layer rows (memory is the risk, not time).
set -u
R=/home/victor/wt-uperf3-am
MI=/home/victor/wt-uperf3-aa/results/m8b_mistral_v3_export
export M125_EXPORT_DIR=/home/victor/IntelligenceRegulation/results/m125_ffn_export_wsl
CUDA_LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
GPU=$R/hashline/target-gpu/release/hashline
SP=$R/results/am_scratch
mkdir -p "$SP"
say () { echo; echo "=== $* ==="; date '+%F %T'; }

say "P3 tamper legs at Mistral width (layer 0, T=16), GPU prover"
HL_GPU=1 LD_LIBRARY_PATH=$CUDA_LD $GPU layer 0 16 --p3 --seed 1 --profile v3 --export $MI --all-tampers 2>&1 \
  | grep -Ei 'tamper|GREEN|RED|W masks|W group|W prox|error|panic'

say "P1 (fast tier), ONE Mistral layer at T=512, GPU, no weight cache"
HL_GPU=1 LD_LIBRARY_PATH=$CUDA_LD /usr/bin/time -v $GPU pass 1 512 --threads 8 --zk --seed 1 --profile v3 --export $MI --proof-out $SP/mi-p1.proof 2>&1 \
  | grep -Ei 'MODE|layer  0|prover phases|commit W|commit A|helpers|zero-check|openings|matmul|mask|PROVE|VERIFY|PROOF sha256|ACCEPT|REJECT|vram|device-side|Maximum resident|error|panic|declined'

say "P3 (full tier), ONE Mistral layer at T=512, GPU"
HL_GPU=1 LD_LIBRARY_PATH=$CUDA_LD /usr/bin/time -v $GPU pass 1 512 --threads 8 --p3 --seed 1 --profile v3 --export $MI --proof-out $SP/mi-p3.proof 2>&1 \
  | grep -Ei 'MODE|layer  0|prover phases|commit W|commit A|helpers|zero-check|openings|matmul|mask|PROVE|VERIFY|PROOF sha256|ACCEPT|REJECT|vram|device-side|Maximum resident|error|panic|declined'

say "sizes and the clear-value scan"
stat -c '%n %s B' $SP/mi-p1.proof $SP/mi-p3.proof
sha256sum $SP/mi-p1.proof $SP/mi-p3.proof
python3 $R/results/am_r0_output_scan.py $SP/mi-p1.proof $SP/mi-p3.proof
rm -f $SP/mi-p1.proof $SP/mi-p3.proof

say "DONE"
