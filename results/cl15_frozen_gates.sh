#!/bin/bash
# [ZK60-CL15] frozen-gate self-check: build the GPU binary, then run the v2
# and zk fixtures ONE AT A TIME (the caller holds /tmp/zk-heavy.lock around
# this whole script), hash each proof, delete the bytes, keep the logs.
set -u
S=/tmp/claude-1000/-home-victor-IntelligenceRegulation/ee339e97-5d60-4550-9623-e998ecce960c/scratchpad
export CUDA_ROOT=/home/victor/cuda-root
export LD_LIBRARY_PATH=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
export CARGO_TARGET_DIR=/home/victor/wt-zk60-cl1/hashline/target-gpu
export CARGO_BUILD_JOBS=2
BIN=$CARGO_TARGET_DIR/release/hashline

echo "== build $(date -Is)"
cargo build --release --offline --features gpu-cuda --manifest-path /home/victor/wt-zk60-cl1/hashline/Cargo.toml > "$S/cl15_build.log" 2>&1
rc=$?
echo "build exit=$rc"
echo $rc > "$S/cl15_build.done"
[ $rc -eq 0 ] || exit $rc

echo "== v2 $(date -Is)  (HL_GPU=1 HL_ZK_CHUNK=1 pass 12 512 --threads 2)"
rm -f "$S/v2.proof"
env HL_GPU=1 HL_ZK_CHUNK=1 "$BIN" pass 12 512 --threads 2 --proof-out "$S/v2.proof" > "$S/cl15_v2.log" 2>&1
rc=$?
echo "v2 exit=$rc"
echo $rc > "$S/cl15_v2.done"
grep -Ei 'gpu:|ACCEPT|REJECT|PROOF sha256|error|panic' "$S/cl15_v2.log" | head -6
if [ -f "$S/v2.proof" ]; then
  echo "v2 sha256 $(sha256sum "$S/v2.proof" | cut -d' ' -f1)  bytes $(stat -c %s "$S/v2.proof")"
  rm -f "$S/v2.proof"
else
  echo "v2 produced NO proof file"
fi

echo "== zk $(date -Is)  (HL_GPU=1 HL_ZK_CHUNK=1 pass 12 512 --threads 2 --zk --seed 1)"
rm -f "$S/zk.proof"
env HL_GPU=1 HL_ZK_CHUNK=1 "$BIN" pass 12 512 --threads 2 --zk --seed 1 --proof-out "$S/zk.proof" > "$S/cl15_zk.log" 2>&1
rc=$?
echo "zk exit=$rc"
echo $rc > "$S/cl15_zk.done"
grep -Ei 'gpu:|ACCEPT|REJECT|PROOF sha256|error|panic' "$S/cl15_zk.log" | head -6
if [ -f "$S/zk.proof" ]; then
  echo "zk sha256 $(sha256sum "$S/zk.proof" | cut -d' ' -f1)  bytes $(stat -c %s "$S/zk.proof")"
  rm -f "$S/zk.proof"
else
  echo "zk produced NO proof file"
fi
echo "== done $(date -Is)"
