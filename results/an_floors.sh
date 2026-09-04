#!/bin/bash
# [UPERF3 lane AN] The EIGHT byte gates on BOTH binaries in the AN worktree, plus
# the function-2 statement's own digest and its CPU/GPU parity. Copied from
# results/am_floors.sh with R pointed at this lane's tree.
# Usage: an_floors.sh <scratch-dir>
set -u

R=/home/victor/wt-uperf3-an
SP="${1:?scratchpad dir required}"
V3=/home/victor/wt-uperf3-aa/results/m8b_test/m125_v3_export
export M125_EXPORT_DIR=/home/victor/IntelligenceRegulation/results/m125_ffn_export_wsl
CUDA_LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
CARGO=$HOME/.cargo/bin/cargo

mkdir -p "$SP"
CPU=$R/hashline/target/release/hashline
GPU=$R/hashline/target-gpu/release/hashline
fail=0

say () { echo; echo "=== $* ==="; date '+%F %T'; }

say "CPU build"
flock /tmp/zk-build.lock $CARGO build --release --manifest-path $R/hashline/Cargo.toml || { echo "FAILURE: CPU build"; exit 1; }

say "GPU build (feature gpu-cuda)"
CUDA_ROOT=/home/victor/cuda-root LD_LIBRARY_PATH=$CUDA_LD \
  CARGO_TARGET_DIR=$R/hashline/target-gpu \
  flock /tmp/zk-build.lock $CARGO build --release --features gpu-cuda --manifest-path $R/hashline/Cargo.toml \
  || { echo "FAILURE: GPU build"; exit 1; }

say "cargo test --release"
flock /tmp/zk-build.lock $CARGO test --release --manifest-path $R/hashline/Cargo.toml 2>&1 | tail -25
[ "${PIPESTATUS[0]}" = 0 ] || { echo "FAILURE: cargo test"; fail=1; }

# gate <name> <ref-sha16> <ref-bytes> <binary> <label> <extra args...>
gate () {
  local name=$1 ref=$2 refb=$3 bin=$4 label=$5; shift 5
  local out=$SP/$label-$name.proof
  say "GATE $name [$label]"
  if [ "$label" = gpu ]; then
    HL_GPU=1 LD_LIBRARY_PATH=$CUDA_LD "$bin" pass 12 512 --threads 8 --proof-out "$out" "$@" 2>&1 \
      | grep -Ei 'PROVE|VERIFY|PROOF sha256|ACCEPT|REJECT|error|panic|MODE'
  else
    "$bin" pass 12 512 --threads 8 --proof-out "$out" "$@" 2>&1 \
      | grep -Ei 'PROVE|VERIFY|PROOF sha256|ACCEPT|REJECT|error|panic|MODE'
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

# [UPERF3-AN] the NEW statement: function 2 gets its OWN digest, and it must be the
# same digest on both binaries (the CPU/GPU parity discipline of every other gate).
say "FUNCTION 2 [cpu] 12x512 --predicate 0:0:-32768"
$CPU pass 12 512 --threads 8 --predicate 0:0:-32768 --seed 1 --profile v3 --export $V3 --proof-out $SP/cpu-f2.proof 2>&1 \
  | grep -Ei 'MODE|PROVE|VERIFY|PROOF sha256|ACCEPT|REJECT|error|panic'
say "FUNCTION 2 [gpu] 12x512 --predicate 0:0:-32768"
HL_GPU=1 LD_LIBRARY_PATH=$CUDA_LD $GPU pass 12 512 --threads 8 --predicate 0:0:-32768 --seed 1 --profile v3 --export $V3 --proof-out $SP/gpu-f2.proof 2>&1 \
  | grep -Ei 'MODE|PROVE|VERIFY|PROOF sha256|ACCEPT|REJECT|gpu:|error|panic'
say "FUNCTION 2 CPU == GPU?"
if cmp -s $SP/cpu-f2.proof $SP/gpu-f2.proof; then echo "BYTE-IDENTICAL"; else echo "FAILURE: function-2 CPU and GPU proofs differ"; fail=1; fi
sha256sum $SP/cpu-f2.proof $SP/gpu-f2.proof
stat -c '%n %s B' $SP/cpu-f2.proof $SP/gpu-f2.proof

say "VERDICT"
if [ $fail = 0 ]; then echo "ALL FLOORS GREEN (8 byte gates + tests + both builds + the function-2 statement)"; else echo "FAILURE: one or more floors RED — see above"; fi
exit $fail
