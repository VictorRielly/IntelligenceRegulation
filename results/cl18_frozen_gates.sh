#!/bin/bash
# [ZK60-CL18] Frozen byte gates at the CL18 source, run ONE AT A TIME under the
# heavy lock (the caller holds /tmp/zk-heavy.lock around this whole script):
#   1. build the GPU binary (the compact pad/scale path is in it, switched OFF);
#   2. the four 12x512 fixtures on GPU with HL_ZK_CHUNK=1 and the switch OFF
#      (v2, v3, zk, zkv3 — must match the frozen digests);
#   3. the two HIDING fixtures again with HL_ZK_COMPACT_PAD=1 (must ALSO match:
#      the compact path is byte-preserving or it is wrong);
#   4. two labelled DIAGNOSTIC runs of the zk fixture with HL_GPU_VERBOSE=1
#      (OFF, ON) — NOT gates, they exist to read the fixture's hiding shapes
#      and per-commit clocks; their digests are checked all the same.
# Every proof is hashed and deleted; logs stay under results/cl18_*.
# Usage: cl18_frozen_gates.sh <scratch-dir>
set -u
R=/home/victor/wt-zk60-cl1
SP="${1:?scratchpad dir required}"
export CUDA_ROOT=/home/victor/cuda-root
export LD_LIBRARY_PATH=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
export CARGO_TARGET_DIR=$R/hashline/target-gpu
export CARGO_BUILD_JOBS=2
export RAYON_NUM_THREADS=2
export M125_EXPORT_DIR=/home/victor/IntelligenceRegulation/results/m125_ffn_export_wsl
V3X=/home/victor/wt-uperf3-aa/results/m8b_test/m125_v3_export
BIN=$CARGO_TARGET_DIR/release/hashline
IDLE_MAX_MB=400
mkdir -p "$SP"
fail=0
CASES=0
say () { echo; echo "=== $* ==="; date '+%F %T'; }

say "identity"
echo "HEAD    $(git --no-pager -C $R rev-parse HEAD)"
echo "dirty   $(git --no-pager -C $R status --porcelain --untracked-files=no | wc -l) tracked file(s) modified"
echo "binary before build $(sha256sum "$BIN" 2>/dev/null | cut -d' ' -f1)"

say "build (cargo build --release --offline --features gpu-cuda, 2 jobs)"
cargo build --release --offline --features gpu-cuda --manifest-path $R/hashline/Cargo.toml > $R/results/cl18_build.log 2>&1
rc=$?
echo "build exit=$rc"
echo $rc > $R/results/cl18_build.done
if [ $rc -ne 0 ]; then echo "FAILURE: build failed; see results/cl18_build.log"; tail -30 $R/results/cl18_build.log; exit 1; fi
echo "binary  $(sha256sum "$BIN" | cut -d' ' -f1)  $(stat -c %s "$BIN") B"

# gate <label> <expect-sha> <expect-bytes> <env...> -- <args...>
gate () {
  local label=$1 esha=$2 eb=$3; shift 3
  local envs=()
  while [ "$1" != "--" ]; do envs+=("$1"); shift; done; shift
  local used
  used=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits | head -1)
  if [ "${used:-9999}" -gt "$IDLE_MAX_MB" ]; then echo "FAILURE: device not idle before $label (${used} MiB used)"; fail=1; return; fi
  local out=$SP/cl18_${label}.proof log=$R/results/cl18_gate_${label}.log
  rm -f "$out"
  echo "--- $label ($(date '+%T')): env ${envs[*]} ; $BIN pass 12 512 --threads 2 $*"
  env "${envs[@]}" "$BIN" pass 12 512 --threads 2 "$@" --proof-out "$out" > "$log" 2>&1
  local rc=$?
  CASES=$((CASES+1))
  local got gotb
  got=$(sha256sum "$out" 2>/dev/null | cut -d' ' -f1); gotb=$(stat -c %s "$out" 2>/dev/null)
  echo "CL18_GATE label=$label exit=$rc sha256=${got:-none} bytes=${gotb:-none} expect=$esha/$eb" | tee -a "$log"
  grep -E 'gpu: ON|PASS|chunked ZK commit|chunked ZK re-encode|zk commit rows' "$log" | head -12
  [ "$rc" = 0 ] || { echo "FAILURE: $label exited $rc"; fail=1; }
  grep -q 'gpu: ON' "$log" || { echo "FAILURE: $label ran without the device"; fail=1; }
  if [ "$got" != "$esha" ] || [ "$gotb" != "$eb" ]; then echo "FAILURE: $label proof moved: ${got:-none}/${gotb:-none}"; fail=1; else echo "MATCH: $label"; fi
  rm -f "$out"
}

V2=50cf7bdfd6b5b182f9c029c3d62087ca9e0e273be218d017609323c15146a17d
V3=5f368db6240e061428a90eccdb22ff456b1507708ef95f1bed39615042973c1d
ZK=021485e4f80ec695ddc0b05423a941e1a165c222efe12aca5bf3cd2f0d02282d
ZKV3=40eb54795e023c77382a31020aac728485daaae2e1b5ec58c3c82d04f94aac17

say "the four frozen fixtures, GPU, HL_ZK_CHUNK=1, compact switch OFF"
gate v2   $V2   66844928 HL_GPU=1 HL_ZK_CHUNK=1 --
gate v3   $V3   70758084 HL_GPU=1 HL_ZK_CHUNK=1 -- --profile v3 --export $V3X
gate zk   $ZK   87228528 HL_GPU=1 HL_ZK_CHUNK=1 -- --zk --seed 1
gate zkv3 $ZKV3 87697008 HL_GPU=1 HL_ZK_CHUNK=1 -- --zk --seed 1 --profile v3 --export $V3X

say "the two hiding fixtures again, compact switch ON (HL_ZK_COMPACT_PAD=1)"
gate zk_compact   $ZK   87228528 HL_GPU=1 HL_ZK_CHUNK=1 HL_ZK_COMPACT_PAD=1 -- --zk --seed 1
gate zkv3_compact $ZKV3 87697008 HL_GPU=1 HL_ZK_CHUNK=1 HL_ZK_COMPACT_PAD=1 -- --zk --seed 1 --profile v3 --export $V3X

say "DIAGNOSTIC (not a gate): the zk fixture with HL_GPU_VERBOSE=1, OFF then ON, for the hiding shapes and per-commit clocks"
gate zk_diag_off $ZK 87228528 HL_GPU=1 HL_ZK_CHUNK=1 HL_GPU_VERBOSE=1 -- --zk --seed 1
gate zk_diag_on  $ZK 87228528 HL_GPU=1 HL_ZK_CHUNK=1 HL_GPU_VERBOSE=1 HL_ZK_COMPACT_PAD=1 -- --zk --seed 1

say "VERDICT"
echo "executed cases: $CASES (6 gates + 2 diagnostics)"
if [ $fail = 0 ]; then echo "CL18 GATES GREEN (four fixtures OFF and both hiding fixtures ON byte-identical to the frozen digests)"; else echo "FAILURE: CL18 GATES RED — see above"; fi
exit $fail
