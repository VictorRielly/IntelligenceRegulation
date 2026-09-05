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
CUDA_ROOT=/home/victor/cuda-root LD_LIBRARY_PATH=$CUDA_LD CARGO_TARGET_DIR=$R/hashline/target-gpu HL_GPU=1 \
  flock /tmp/zk-build.lock cargo test --release --features gpu-cuda --manifest-path $R/hashline/Cargo.toml --test zk60_gpu_commit 2>&1 | tail -12
[ "${PIPESTATUS[0]}" = 0 ] || { echo "FAILURE: CL1 GPU oracle suite"; fail=1; }

# gate <name> <ref-sha16> <ref-bytes> <binary> <label> <extra args...>
gate () {
  local name=$1 ref=$2 refb=$3 bin=$4 label=$5; shift 5
  local out=$SP/$label-$name.proof
  say "GATE $name [$label]"
  case "$label" in
    gpu)       HL_GPU=1 LD_LIBRARY_PATH=$CUDA_LD "$bin" pass 12 512 --threads 8 --proof-out "$out" "$@" 2>&1 | grep -Ei 'gpu:|PROVE|ACCEPT|REJECT|error|panic' ;;
    gpu-zkchunk) HL_GPU=1 HL_ZK_CHUNK=1 LD_LIBRARY_PATH=$CUDA_LD "$bin" pass 12 512 --threads 8 --proof-out "$out" "$@" 2>&1 | grep -Ei 'gpu:|PROVE|ACCEPT|REJECT|error|panic' ;;
    *)         "$bin" pass 12 512 --threads 8 --proof-out "$out" "$@" 2>&1 | grep -Ei 'PROVE|ACCEPT|REJECT|error|panic' ;;
  esac
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

for L in cpu gpu gpu-zkchunk; do
  B=$CPU; [ "$L" = cpu ] || B=$GPU
  gate v2   50cf7bdfd6b5b182 66844928 "$B" $L
  gate v3   5f368db6240e0614 70758084 "$B" $L --profile v3 --export $V3
  gate zk   021485e4f80ec695 87228528 "$B" $L --zk --seed 1
  gate zkv3 40eb54795e023c77 87697008 "$B" $L --zk --seed 1 --profile v3 --export $V3
done

say "VERDICT"
if [ $fail = 0 ]; then echo "ALL CL1 FLOORS GREEN (12 byte gates + oracle suite + tests + both builds)"; else echo "FAILURE: one or more CL1 floors RED — see above"; fi
exit $fail
