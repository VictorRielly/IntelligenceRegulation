#!/bin/bash
# [FSP-HOST] THE GATE THE TWELVE DO NOT REACH. At the 12x512 fixture the W
# commitment is 75.5 MB of encoding, which is under the twelve gates'
# forced threshold (HL_GPU_CHUNK_BYTES=100000000), so W always takes the
# RESIDENT upload (`upload_narrow`) and never `commit_chunked_upload` —
# the route the 8B shape uses. Forcing the threshold to 10 MB puts W on
# the chunked route at the fixture shape, so the frozen v3 digests become
# an end-to-end check of the plane source THERE too.
#
# Both arms are run, so the gate also shows the two routes agree:
#   HL_FSP4_PLANES=1 (the int8 planes)  and  =0 (the inherited Vec<Fp>).
# Note `HL_GPU_CHUNK_ROWS` is floored at 128 in cuda.rs, so 9-row W is one
# chunk whatever is asked; the multi-piece arithmetic is what the unit
# oracles cover (`cargo test --lib plane`).
# Usage: fsp4_planes_chunked_gate.sh <scratch-dir>
set -u
R=/home/victor/wt-fsp-host
SP="${1:?scratch dir required}"
V3=/home/victor/wt-uperf3-aa/results/m8b_test/m125_v3_export
export M125_EXPORT_DIR=/home/victor/IntelligenceRegulation/results/m125_ffn_export_wsl
CUDA_LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
GPU=${FSP_GPU_BIN:-$R/hashline/target-gpu/release/hashline}
mkdir -p "$SP"
fail=0
echo "=== box ==="; date '+%F %T'; uptime; nvidia-smi --query-gpu=memory.used --format=csv,noheader
gate () {
  local name=$1 ref=$2 refb=$3 arm=$4; shift 4
  local out=$SP/chunkplanes-$name-$arm.proof
  echo; echo "=== GATE $name [HL_FSP4_PLANES=$arm, W forced chunked] ==="; date '+%F %T'
  HL_GPU=1 LD_LIBRARY_PATH=$CUDA_LD HL_GPU_CHUNK_BYTES=10000000 HL_GPU_CHUNK_ROWS=128 \
    HL_FSP4_PLANES=$arm HL_FSP4_TIMING=1 HL_CONV_VERBOSE=1 \
    "$GPU" pass 12 512 --threads 8 --proof-out "$out" "$@" 2>&1 \
    | grep -Ei 'streamed commit|FSP4|conv W  l00|PROVE|ACCEPT|REJECT|error|panic|declined'
  if [ ! -f "$out" ]; then echo "FAILURE: $name [$arm] produced no proof"; fail=1; return; fi
  local got gotb
  got=$(sha256sum "$out" | cut -c1-16)
  gotb=$(stat -c %s "$out")
  if [ "$got" = "$ref" ] && [ "$gotb" = "$refb" ]; then
    echo "GATE OK   $name [planes=$arm]  $got  $gotb B"
  else
    echo "FAILURE: GATE $name [planes=$arm] got $got / $gotb B, want $ref / $refb B"
    fail=1
  fi
  rm -f "$out"
}
for arm in 1 0; do
  gate v3   5f368db6240e0614 70758084 $arm --profile v3 --export $V3
  gate zkv3 40eb54795e023c77 87697008 $arm --zk --seed 1 --profile v3 --export $V3
done
echo; echo "=== VERDICT ==="
if [ $fail = 0 ]; then echo "CHUNKED-W PLANE GATES GREEN (4: v3 and zk-v3, both arms)"; else echo "FAILURE: one or more chunked-W plane gates RED"; fi
exit $fail
