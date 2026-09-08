#!/bin/bash
# [ZK60-CL18] The compact pad/scale output, A/B on ONE binary at the Mistral
# one-layer P3 shape (d 4096 / f 14336, T=512, GPU, HL_ZK_CHUNK=1, --threads 2):
# HL_ZK_COMPACT_PAD=1 (compact) vs unset (the full-width reference), ABAB x REPS
# — the CL7 protocol (results/cl7_reenc_ab.sh) with two threads. The proof MUST
# be byte-identical ACROSS ARMS (hard gate); it is also compared with CL7's
# frozen Mistral P3 digest 190e85a1.. / 40,251,860 B (reported; a difference
# there would be a finding about the source or the thread count, not about
# the switch). The changed phases are the prover's `chunked ZK commit` and
# `chunked ZK re-encode + gather` lines; the HASHLINE_TIMING prove_s and
# proof_ready_s clocks are the end-to-end context. Two-thread laptop
# diagnostic seconds, single box, not a p95.
# Usage: cl18_reenc_ab.sh <scratch-dir> [reps=2]
set -u
R=/home/victor/wt-zk60-cl1
SP="${1:?scratchpad dir required}"
REPS="${2:-2}"
MI=/home/victor/wt-uperf3-aa/results/m8b_mistral_v3_export
export M125_EXPORT_DIR=/home/victor/IntelligenceRegulation/results/m125_ffn_export_wsl
export RAYON_NUM_THREADS=2
CUDA_LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
GPU=$R/hashline/target-gpu/release/hashline
CL7_SHA=190e85a1d3bebdc3dc9ba74ad3d1cf4adf4edf4b7ec9c95e36af72f3700e1f2e
CL7_B=40251860
IDLE_MAX_MB=400
mkdir -p "$SP"
fail=0
say () { echo; echo "=== $* ==="; date '+%F %T'; }

say "identity"
echo "HEAD    $(git --no-pager -C $R rev-parse HEAD)"
echo "dirty   $(git --no-pager -C $R status --porcelain --untracked-files=no | wc -l) tracked file(s) modified"
echo "binary  $(sha256sum "$GPU" | cut -d' ' -f1)  $(stat -c %s "$GPU") B"

CASES=0
FIRST_SHA=""; FIRST_B=""
for i in $(seq 1 "$REPS"); do
  for arm in compact reference; do
    used=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits | head -1)
    if [ "${used:-9999}" -gt "$IDLE_MAX_MB" ]; then echo "FAILURE: device not idle before $arm rep $i (${used} MiB used)"; fail=1; continue; fi
    log=$R/results/cl18_ab_${arm}_r${i}.log; out=$SP/cl18_${arm}_r${i}.proof
    rm -f "$out"
    echo "--- $arm rep $i ($(date '+%T'))"
    if [ "$arm" = compact ]; then
      HL_GPU=1 HL_GPU_VERBOSE=1 HL_ZK_CHUNK=1 HL_ZK_COMPACT_PAD=1 LD_LIBRARY_PATH=$CUDA_LD "$GPU" pass 1 512 --threads 2 --p3 --seed 1 --profile v3 --export $MI --proof-out "$out" > "$log" 2>&1
    else
      HL_GPU=1 HL_GPU_VERBOSE=1 HL_ZK_CHUNK=1 LD_LIBRARY_PATH=$CUDA_LD "$GPU" pass 1 512 --threads 2 --p3 --seed 1 --profile v3 --export $MI --proof-out "$out" > "$log" 2>&1
    fi
    rc=$?
    CASES=$((CASES+1))
    got=$(sha256sum "$out" 2>/dev/null | cut -d' ' -f1); gotb=$(stat -c %s "$out" 2>/dev/null)
    { echo "CL18_RUN arm=$arm rep=$i exit=$rc sha256=${got:-none} bytes=${gotb:-none}"; } | tee -a "$log"
    grep -E 'gpu: ON|PASS-V3|vram peak|chunked ZK commit|chunked ZK re-encode' "$log" | head -9
    grep -E '^HASHLINE_TIMING' "$log" | head -1
    [ "$rc" = 0 ] || { echo "FAILURE: $arm rep $i exited $rc"; fail=1; }
    grep -q 'gpu: ON' "$log" || { echo "FAILURE: $arm rep $i ran without the device"; fail=1; }
    if [ -z "$FIRST_SHA" ]; then FIRST_SHA=$got; FIRST_B=$gotb; fi
    if [ "$got" != "$FIRST_SHA" ] || [ "$gotb" != "$FIRST_B" ]; then echo "FAILURE: $arm rep $i proof differs across arms: ${got:-none}/${gotb:-none} vs ${FIRST_SHA}/${FIRST_B}"; fail=1; fi
    if [ "$got" = "$CL7_SHA" ] && [ "$gotb" = "$CL7_B" ]; then echo "note: equals CL7's frozen Mistral P3 digest"; else echo "NOTE: differs from CL7's frozen Mistral P3 digest ($CL7_SHA/$CL7_B) — a finding to explain, not an arm difference"; fi
    rm -f "$out"
  done
done

say "VERDICT"
echo "executed cases: $CASES"
if [ $fail = 0 ]; then echo "CL18 A/B GREEN (both arms byte-identical: $FIRST_SHA / $FIRST_B B)"; else echo "FAILURE: CL18 A/B RED — see above"; fi
exit $fail
