#!/bin/bash
# [UPERF3 AL] rung 3: the crate tests, the twelve byte gates on both
# binaries, then the 32-layer 8B GPU pass BEFORE and AFTER this lane — one
# binary, one session, a FRESH --wcache directory in each arm (so neither
# arm is served a warm weight commitment), exactly as AJ's
# results/hashline_hostwall_r4.sh did.
set -u
R=/home/victor/wt-uperf3-al
CUDA_LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
GPU=$R/hashline/target-gpu/release/hashline
M8B=/home/victor/wt-uperf3-aa/results/m8b_mistral_v3_export
SP=$R/results/scratch_r3
mkdir -p $SP
say () { echo; echo "=== $* ==="; date '+%F %T'; }

say "cargo test --release"
cargo test --release --manifest-path $R/hashline/Cargo.toml 2>&1 | tail -12
[ "${PIPESTATUS[0]}" = 0 ] || { echo "FAILURE: cargo test"; exit 1; }

$R/results/hashline_convert_floors.sh $SP || { echo "FAILURE: gates RED — the 8B passes are NOT run"; exit 1; }

pass8b () {
  local name=$1; shift
  say "8B PASS 32x512 GPU — $name"
  rm -rf $SP/wc_$name; mkdir -p $SP/wc_$name
  env "$@" HL_GPU=1 HL_GPU_VERBOSE=1 HL_CONV_VERBOSE=1 LD_LIBRARY_PATH=$CUDA_LD \
    /usr/bin/time -v $GPU pass 32 512 --profile v3 --export $M8B --threads 8 \
    --wcache $SP/wc_$name --proof-out $SP/p_$name.bin 2>&1 \
    | grep -vE "^\[UPERF3-(XX|AC|AJ)\]   " \
    | grep -E "UPERF3-AL|PASS-V3|PROVE|PROOF sha256|gpu device|gpu chunked|prover phases|^      |Maximum resident|Elapsed|wcache|declined|WARNING"
  sha256sum $SP/p_$name.bin
  ls -l $SP/p_$name.bin
  rm -f $SP/p_$name.bin
  rm -rf $SP/wc_$name
}

pass8b before HL_AL_POOL=0 HL_AL_I8FOLD=0
pass8b after  HL_DUMMY=1
say "DONE"
