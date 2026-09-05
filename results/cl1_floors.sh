#!/bin/bash
# [ZK60-CL1] The lane's floors: both builds, the crate tests, the four frozen
# byte gates on BOTH binaries, the same four with the HIDING commitment's
# chunking FORCED (HL_ZK_CHUNK=1) so the frozen fixtures exercise the new
# code, and the CL1 GPU oracle suite including its negative control.
# Usage: cl1_floors.sh <scratch-dir>
set -u
R=/home/victor/wt-zk60-cl1
SP="${1:?scratchpad dir required}"
V3=/home/victor/wt-uperf3-aa/results/m8b_test/m125_v3_export
export M125_EXPORT_DIR=/home/victor/IntelligenceRegulation/results/m125_ffn_export_wsl
CUDA_LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib

mkdir -p "$SP"
CPU=$R/hashline/target/release/hashline
GPU=$R/hashline/target-gpu/release/hashline
fail=0
say () { echo; echo "=== $* ==="; date '+%F %T'; }

say "CPU build"
flock /tmp/zk-build.lock cargo build --release --manifest-path $R/hashline/Cargo.toml || { echo "FAILURE: CPU build"; exit 1; }

say "GPU build (feature gpu-cuda)"
CUDA_ROOT=/home/victor/cuda-root LD_LIBRARY_PATH=$CUDA_LD \
  CARGO_TARGET_DIR=$R/hashline/target-gpu \
  flock /tmp/zk-build.lock cargo build --release --features gpu-cuda --manifest-path $R/hashline/Cargo.toml \
  || { echo "FAILURE: GPU build"; exit 1; }

say "cargo test --release (CPU)"
# record EVERY binary's result line: `tail` hid the lib suite's count on the
# first run, which left the log unable to show what the exit code had checked.
flock /tmp/zk-build.lock cargo test --release --manifest-path $R/hashline/Cargo.toml 2>&1 | grep -E '^test result:|^error|panicked' 
[ "${PIPESTATUS[0]}" = 0 ] || { echo "FAILURE: cargo test"; fail=1; }

say "CL1 GPU oracle suite (chunked hiding commit vs the CPU, + negative control)"
CUDA_ROOT=/home/victor/cuda-root LD_LIBRARY_PATH=$CUDA_LD CARGO_TARGET_DIR=$R/hashline/target-gpu HL_GPU=1 HL_GPU_REQUIRED=1 \
  flock /tmp/zk-build.lock cargo test --release --features gpu-cuda --manifest-path $R/hashline/Cargo.toml --test zk60_gpu_commit 2>&1 | tail -12
[ "${PIPESTATUS[0]}" = 0 ] || { echo "FAILURE: CL1 GPU oracle suite"; fail=1; }

# [ZK60-CL4 review] gate <name> <ref-sha256-FULL> <ref-bytes> <binary> <label> <args...>
#
# The first version compared `cut -c1-16` of the digest and ignored the proving
# subprocess's exit code entirely, so a truncated match or a crashed run that
# still left a file behind could have passed. It now checks, for every gate:
#   * the proving subprocess's EXIT CODE
#   * the verifier's ACCEPT line
#   * device execution (`gpu: ON`) whenever the label is a GPU one
#   * the FULL SHA-256 and the exact byte length
#   * a freshly produced artifact (the output is removed before the run)
CASES=0
gate () {
  local name=$1 ref=$2 refb=$3 bin=$4 label=$5; shift 5
  local out=$SP/$label-$name.proof
  local log=$SP/$label-$name.out
  say "GATE $name [$label]"
  rm -f "$out"
  case "$label" in
    gpu)         HL_GPU=1 LD_LIBRARY_PATH=$CUDA_LD "$bin" pass 12 512 --threads 8 --proof-out "$out" "$@" > "$log" 2>&1 ;;
    gpu-zkchunk) HL_GPU=1 HL_ZK_CHUNK=1 LD_LIBRARY_PATH=$CUDA_LD "$bin" pass 12 512 --threads 8 --proof-out "$out" "$@" > "$log" 2>&1 ;;
    *)           "$bin" pass 12 512 --threads 8 --proof-out "$out" "$@" > "$log" 2>&1 ;;
  esac
  local rc=$?
  CASES=$((CASES+1))
  grep -Ei 'gpu:|PROVE|ACCEPT|REJECT|error|panic' "$log" | head -4
  if [ "$rc" != 0 ]; then echo "FAILURE: $name [$label] prover exited $rc"; fail=1; return; fi
  if ! grep -q 'ACCEPT' "$log"; then echo "FAILURE: $name [$label] no ACCEPT from the verifier"; fail=1; return; fi
  case "$label" in
    gpu|gpu-zkchunk)
      if ! grep -q 'gpu: ON' "$log"; then
        echo "FAILURE: $name [$label] ran WITHOUT a device (no 'gpu: ON'); a CPU fallback is not a GPU gate"
        fail=1; return
      fi ;;
  esac
  if [ ! -f "$out" ]; then echo "FAILURE: $name [$label] produced no proof"; fail=1; return; fi
  local got gotb
  got=$(sha256sum "$out" | cut -d" " -f1)
  gotb=$(stat -c %s "$out")
  if [ "$got" = "$ref" ] && [ "$gotb" = "$refb" ]; then
    echo "GATE OK   $name [$label]  $got  $gotb B"
  else
    echo "FAILURE: GATE $name [$label]"
    echo "   got  $got / $gotb B"
    echo "   want $ref / $refb B"
    fail=1
  fi
  rm -f "$out" "$log"
}

for L in cpu gpu gpu-zkchunk; do
  B=$CPU; [ "$L" = cpu ] || B=$GPU
  gate v2   50cf7bdfd6b5b182f9c029c3d62087ca9e0e273be218d017609323c15146a17d 66844928 "$B" $L
  gate v3   5f368db6240e061428a90eccdb22ff456b1507708ef95f1bed39615042973c1d 70758084 "$B" $L --profile v3 --export $V3
  gate zk   021485e4f80ec695ddc0b05423a941e1a165c222efe12aca5bf3cd2f0d02282d 87228528 "$B" $L --zk --seed 1
  gate zkv3 40eb54795e023c77382a31020aac728485daaae2e1b5ec58c3c82d04f94aac17 87697008 "$B" $L --zk --seed 1 --profile v3 --export $V3
done

say "VERDICT"
echo "executed byte-gate cases: $CASES (expect 12)"
[ "$CASES" = 12 ] || { echo "FAILURE: expected 12 gate cases, ran $CASES"; fail=1; }
if [ $fail = 0 ]; then echo "ALL CL1 FLOORS GREEN (12 byte gates + oracle suite + tests + both builds)"; else echo "FAILURE: one or more CL1 floors RED — see above"; fi
exit $fail
