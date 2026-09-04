#!/bin/bash
# [UPERF3-AI rung 3] The four byte gates on BOTH binaries, in lane AI's worktree.
# A retarget of scripts/floors_round13_merge.sh (the orchestrator's copy, unedited)
# onto /home/victor/wt-uperf3-ai: same statements, same reference digests and byte
# counts, same grep. Binaries are assumed already built (this script does not build).
set -u

R=/home/victor/wt-uperf3-ai
SP="${1:?scratchpad dir required}"
V3=/home/victor/wt-uperf3-aa/results/m8b_test/m125_v3_export
export M125_EXPORT_DIR=/home/victor/IntelligenceRegulation/results/m125_ffn_export_wsl
CUDA_LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib

mkdir -p "$SP"
CPU=$R/hashline/target/release/hashline
GPU=$R/hashline/target-gpu/release/hashline
fail=0

say () { echo; echo "=== $* ==="; date '+%F %T'; }

say "cargo test --release"
cargo test --release --manifest-path $R/hashline/Cargo.toml 2>&1 | grep -E 'test result|running [0-9]+ tests|^error'
[ "${PIPESTATUS[0]}" = 0 ] || { echo "FAILURE: cargo test"; fail=1; }

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

say "VERDICT"
if [ $fail = 0 ]; then echo "ALL EIGHT BYTE GATES GREEN (+ tests)"; else echo "FAILURE: one or more gates RED — see above"; fi
exit $fail
