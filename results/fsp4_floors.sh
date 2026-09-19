#!/bin/bash
# [FSP-HOST] The TWELVE byte gates in this lane's worktree: the four frozen
# 12x512 fixtures on the CPU binary, the same four on the GPU binary, and
# the same four with the chunked path forced small.
# Copy of results/fsp2_floors.sh re-pointed at /home/victor/wt-fsp-host.
# The BUILDS are NOT here (results/fsp4_build.sh does them), so this script
# never takes /tmp/zk-build.lock and may be wrapped in the heavy lock.
# Usage: fsp4_floors.sh <scratch-dir>
set -u
R=/home/victor/wt-fsp-host
SP="${1:?scratch dir required}"
V3=/home/victor/wt-uperf3-aa/results/m8b_test/m125_v3_export
export M125_EXPORT_DIR=/home/victor/IntelligenceRegulation/results/m125_ffn_export_wsl
CUDA_LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
mkdir -p "$SP"
# FSP_CPU_BIN / FSP_GPU_BIN override the binaries, so the SAME twelve gates
# can be run against a saved pre-change build (the baseline arm).
CPU=${FSP_CPU_BIN:-$R/hashline/target/release/hashline}
GPU=${FSP_GPU_BIN:-$R/hashline/target-gpu/release/hashline}
fail=0
say () { echo; echo "=== $* ==="; date '+%F %T'; }
gate () {
  local name=$1 ref=$2 refb=$3 bin=$4 label=$5; shift 5
  local out=$SP/$label-$name.proof
  say "GATE $name [$label]"
  if [ "$label" = gpu ]; then
    HL_GPU=1 LD_LIBRARY_PATH=$CUDA_LD "$bin" pass 12 512 --threads 8 --proof-out "$out" "$@" 2>&1 \
      | grep -Ei 'PROVE|VERIFY|PROOF sha256|ACCEPT|REJECT|error|panic'
  else
    "$bin" pass 12 512 --threads 8 --proof-out "$out" "$@" 2>&1 \
      | grep -Ei 'PROVE|VERIFY|PROOF sha256|ACCEPT|REJECT|error|panic'
  fi
  if [ ! -f "$out" ]; then echo "FAILURE: $name [$label] produced no proof"; fail=1; return; fi
  local got gotb
  got=$(sha256sum "$out" | cut -c1-16)
  gotb=$(stat -c %s "$out")
  if [ "$got" = "$ref" ] && [ "$gotb" = "$refb" ]; then
    echo "GATE OK   $name [$label]  $got  $gotb B"
  else
    echo "FAILURE: GATE $name [$label] got $got / $gotb B, want $ref / $refb B"
    fail=1
  fi
  rm -f "$out"
}
for L in cpu gpu; do
  B=$CPU; [ $L = gpu ] && B=$GPU
  gate v2   50cf7bdfd6b5b182 66844928 "$B" $L
  gate v3   5f368db6240e0614 70758084 "$B" $L --profile v3 --export $V3
  gate zk   021485e4f80ec695 87228528 "$B" $L --zk --seed 1
  gate zkv3 40eb54795e023c77 87697008 "$B" $L --zk --seed 1 --profile v3 --export $V3
done
export HL_GPU_CHUNK_BYTES=100000000
export HL_GPU_CHUNK_ROWS=128
gate v2-chunked   50cf7bdfd6b5b182 66844928 "$GPU" gpu
gate v3-chunked   5f368db6240e0614 70758084 "$GPU" gpu --profile v3 --export $V3
gate zk-chunked   021485e4f80ec695 87228528 "$GPU" gpu --zk --seed 1
gate zkv3-chunked 40eb54795e023c77 87697008 "$GPU" gpu --zk --seed 1 --profile v3 --export $V3
unset HL_GPU_CHUNK_BYTES HL_GPU_CHUNK_ROWS

say "VERDICT"
if [ $fail = 0 ]; then echo "ALL TWELVE BYTE GATES GREEN (8 standard + 4 chunked-forced)"; else echo "FAILURE: one or more gates RED"; fi
exit $fail
