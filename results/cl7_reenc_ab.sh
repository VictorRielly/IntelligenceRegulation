#!/bin/bash
# [ZK60-CL7] The fused/pruned hiding opening, A/B on ONE binary: the same
# Mistral layer (d 4096 / f 14336, T=512, P3, GPU, chunk 128) with
# HL_ZK_FUSE_GATHER unset (fused, the new default) and =0 (the CL1 reference
# form), ABAB x REPS. The proof must be byte-identical across arms (190e85a1..
# / 40,251,860 B); the prover's `chunked ZK re-encode + gather` lines are the
# changed phase, the PROVE clock is the end-to-end context.
# Usage: cl7_reenc_ab.sh <scratch-dir> [reps=2]
set -u
R=/home/victor/wt-zk60-cl1
SP="${1:?scratchpad dir required}"
REPS="${2:-2}"
MI=/home/victor/wt-uperf3-aa/results/m8b_mistral_v3_export
export M125_EXPORT_DIR=/home/victor/IntelligenceRegulation/results/m125_ffn_export_wsl
CUDA_LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
GPU=$R/hashline/target-gpu/release/hashline
EXPECT_SHA=190e85a1d3bebdc3dc9ba74ad3d1cf4adf4edf4b7ec9c95e36af72f3700e1f2e
EXPECT_B=40251860
IDLE_MAX_MB=400
mkdir -p "$SP"
fail=0
say () { echo; echo "=== $* ==="; date '+%F %T'; }

say "identity"
echo "HEAD    $(git --no-pager -C $R rev-parse HEAD)"
echo "dirty   $(git --no-pager -C $R status --porcelain --untracked-files=no | wc -l) tracked file(s) modified"
echo "binary  $(sha256sum "$GPU" | cut -d' ' -f1)  $(stat -c %s "$GPU") B"

CASES=0
for i in $(seq 1 "$REPS"); do
  for arm in fused reference; do
    used=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits | head -1)
    if [ "${used:-9999}" -gt "$IDLE_MAX_MB" ]; then echo "FAILURE: device not idle before $arm rep $i (${used} MiB used)"; fail=1; continue; fi
    log=$R/results/cl7_ab_${arm}_r${i}.log; out=$SP/cl7_${arm}_r${i}.proof
    rm -f "$out"
    echo "--- $arm rep $i ($(date '+%T'))"
    if [ "$arm" = fused ]; then
      HL_GPU=1 HL_GPU_VERBOSE=1 LD_LIBRARY_PATH=$CUDA_LD "$GPU" pass 1 512 --threads 8 --p3 --seed 1 --profile v3 --export $MI --proof-out "$out" > "$log" 2>&1
    else
      HL_GPU=1 HL_GPU_VERBOSE=1 HL_ZK_FUSE_GATHER=0 LD_LIBRARY_PATH=$CUDA_LD "$GPU" pass 1 512 --threads 8 --p3 --seed 1 --profile v3 --export $MI --proof-out "$out" > "$log" 2>&1
    fi
    rc=$?
    CASES=$((CASES+1))
    got=$(sha256sum "$out" 2>/dev/null | cut -d' ' -f1); gotb=$(stat -c %s "$out" 2>/dev/null)
    { echo "CL7_RUN arm=$arm rep=$i exit=$rc sha256=${got:-none} bytes=${gotb:-none}"; } | tee -a "$log"
    grep -E 'gpu: ON|PASS-V3|vram peak|chunked ZK re-encode' "$log" | head -6
    [ "$rc" = 0 ] || { echo "FAILURE: $arm rep $i exited $rc"; fail=1; }
    grep -q 'gpu: ON' "$log" || { echo "FAILURE: $arm rep $i ran without the device"; fail=1; }
    if [ "$got" != "$EXPECT_SHA" ] || [ "$gotb" != "$EXPECT_B" ]; then echo "FAILURE: $arm rep $i proof moved: ${got:-none}/${gotb:-none}"; fail=1; fi
    rm -f "$out"
  done
done

say "VERDICT"
echo "executed cases: $CASES"
if [ $fail = 0 ]; then echo "CL7 A/B GREEN (both arms byte-identical to the frozen Mistral P3 proof)"; else echo "FAILURE: CL7 A/B RED — see above"; fi
exit $fail
