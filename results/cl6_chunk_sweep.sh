#!/bin/bash
# [ZK60-CL6] The chunk-row sweep, measured. Two halves:
#
#   1. BYTE IDENTITY at the frozen 12x512 zkv3 fixture with chunking FORCED
#      (HL_ZK_CHUNK=1) at every choice: the proof must be the frozen
#      40eb5479.. / 87,697,008 B whatever the chunk rows. A choice that moved
#      the digest would disqualify the whole sweep.
#   2. TIME AND VRAM at one Mistral layer (d 4096 / f 14336, T=512, P3, GPU)
#      where the commitments chunk BY SIZE: ABAB order over the choices, REPS
#      repeats, HL_GPU_VERBOSE=1 so the prover prints its per-commit chunked
#      timings and its `vram after ...` lines. Each run records its proof's
#      full sha256 + length; `hashline_cl_chunk_sweep.py measure` refuses to
#      tabulate if any run's proof differs.
#
# SAFETY: the planner's chunked component is printed for every choice BEFORE
# any run, and a choice is SKIPPED (not attempted) when planner component +
# the measured non-commit reserve exceeds MAX_PREDICTED_MB. nvidia-smi must
# read idle before each Mistral run. Nothing here touches the 8B pass.
#
# Usage: cl6_chunk_sweep.sh <scratch-dir> [reps=2] [choices="128 256 512"]
set -u
R=/home/victor/wt-zk60-cl1
SP="${1:?scratchpad dir required}"
REPS="${2:-2}"
CHOICES="${3:-128 256 512}"
V3=/home/victor/wt-uperf3-aa/results/m8b_test/m125_v3_export
MI=/home/victor/wt-uperf3-aa/results/m8b_mistral_v3_export
export M125_EXPORT_DIR=/home/victor/IntelligenceRegulation/results/m125_ffn_export_wsl
CUDA_LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
GPU=$R/hashline/target-gpu/release/hashline
# [MEASURED, CL1 rung 5] whole-layer peak 5,182 MB at chunk 128 against a
# 1,563 MiB chunked W component: the non-commit residency.
RESERVE_MB=3620
MAX_PREDICTED_MB=7000
IDLE_MAX_MB=400
FROZEN_SHA=40eb54795e023c77382a31020aac728485daaae2e1b5ec58c3c82d04f94aac17
FROZEN_B=87697008
mkdir -p "$SP"
fail=0
say () { echo; echo "=== $* ==="; date '+%F %T'; }

say "identity"
echo "HEAD    $(git --no-pager -C $R rev-parse HEAD)"
echo "dirty   $(git --no-pager -C $R status --porcelain --untracked-files=no | wc -l) tracked file(s) modified"
echo "binary  $(sha256sum "$GPU" | cut -d' ' -f1)  $(stat -c %s "$GPU") B"
echo "choices $CHOICES  reps $REPS"

say "planner: chunked W component per choice at Mistral width (no device touched)"
declare -A PRED
for c in $CHOICES; do
  mib=$(python3 $R/scripts/hashline_memory_plan.py --p3-weights 4096 14336 --ntt-max-log 16 --mode chunked --chunk-rows "$c" \
        | python3 -c 'import json,sys; print(int(json.load(sys.stdin)["component_peak_accounted_bytes"]/1048576))')
  PRED[$c]=$((mib + RESERVE_MB))
  echo "choice $c: W component $mib MiB + reserve $RESERVE_MB = predicted ${PRED[$c]} MB whole-layer (limit $MAX_PREDICTED_MB)"
done

say "half 1: frozen zkv3 fixture, chunking FORCED, every choice"
for c in $CHOICES 1024; do
  out=$SP/zkv3_c$c.proof; log=$SP/zkv3_c$c.out
  rm -f "$out"
  HL_GPU=1 HL_ZK_CHUNK=1 HL_GPU_CHUNK_ROWS=$c LD_LIBRARY_PATH=$CUDA_LD "$GPU" pass 12 512 --threads 8 --zk --seed 1 --profile v3 --export $V3 --proof-out "$out" > "$log" 2>&1
  rc=$?
  got=$(sha256sum "$out" 2>/dev/null | cut -d' ' -f1); gotb=$(stat -c %s "$out" 2>/dev/null)
  if [ "$rc" = 0 ] && grep -q 'gpu: ON' "$log" && grep -q ACCEPT "$log" && [ "$got" = "$FROZEN_SHA" ] && [ "$gotb" = "$FROZEN_B" ]; then
    echo "GATE OK   zkv3 forced-chunk rows=$c  $got  $gotb B"
  else
    echo "FAILURE: zkv3 forced-chunk rows=$c rc=$rc got ${got:-none}/${gotb:-none} (log $log)"; fail=1
  fi
  rm -f "$out"
done

say "half 2: one Mistral layer, P3, GPU, ABAB x $REPS"
CASES=0
for i in $(seq 1 "$REPS"); do
  for c in $CHOICES; do
    if [ "${PRED[$c]}" -gt "$MAX_PREDICTED_MB" ]; then echo "SKIP choice $c: predicted ${PRED[$c]} MB > $MAX_PREDICTED_MB"; continue; fi
    used=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits | head -1)
    if [ "${used:-9999}" -gt "$IDLE_MAX_MB" ]; then echo "FAILURE: device not idle before choice $c rep $i (${used} MiB used)"; fail=1; continue; fi
    log=$R/results/cl6_sweep_p3_c${c}_r${i}.log; out=$SP/mi_c${c}_r${i}.proof
    rm -f "$out"
    echo "--- choice $c rep $i ($(date '+%T'))"
    HL_GPU=1 HL_GPU_VERBOSE=1 HL_GPU_CHUNK_ROWS=$c LD_LIBRARY_PATH=$CUDA_LD "$GPU" pass 1 512 --threads 8 --p3 --seed 1 --profile v3 --export $MI --proof-out "$out" > "$log" 2>&1
    rc=$?
    CASES=$((CASES+1))
    { echo "CL6_RUN chunk_rows=$c rep=$i exit=$rc sha256=$(sha256sum "$out" 2>/dev/null | cut -d' ' -f1) bytes=$(stat -c %s "$out" 2>/dev/null)"; } | tee -a "$log"
    grep -E 'gpu: ON|PASS-V3|vram peak|chunked ZK commit rows|chunked ZK re-encode' "$log" | head -8
    [ "$rc" = 0 ] || { echo "FAILURE: choice $c rep $i exited $rc"; fail=1; }
    grep -q 'gpu: ON' "$log" || { echo "FAILURE: choice $c rep $i ran without the device"; fail=1; }
    rm -f "$out"
  done
done

say "VERDICT"
echo "executed Mistral cases: $CASES"
if [ $fail = 0 ]; then echo "CL6 SWEEP GREEN (frozen fixture byte-identical at every choice; Mistral runs recorded)"; else echo "FAILURE: CL6 sweep RED — see above"; fi
exit $fail
