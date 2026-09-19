#!/bin/bash
# [FSP-HOST] The second pass over item (a), after the plane fill's task
# granularity was fixed (one task per 64 KB, not one per block row, plus a
# single split copy when a block's rows are contiguous in the plane).
# Only what the change can touch: the builds, the two byte-image oracles,
# the twelve byte gates, the chunked-W plane gate, and both A/Bs.
# Same lock discipline as fsp4_c4_drive.sh: cargo under the build lock and
# nothing else; runs under the heavy lock and nothing else.
# Usage: fsp4_c5_drive.sh <tag>
set -u
R=/home/victor/wt-fsp-host
TAG="${1:?tag required}"
SP=/tmp/claude-1000/-home-victor-IntelligenceRegulation/e277dbc7-36bc-4ae1-8184-db91a6d569e4/scratchpad/fsp4$TAG
CARGO=/home/victor/.cargo/bin/cargo
CUDA_LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
GENV="env CUDA_ROOT=/home/victor/cuda-root LD_LIBRARY_PATH=$CUDA_LD CARGO_TARGET_DIR=$R/hashline/target-gpu"
mkdir -p "$SP"

step () {
  local stem=$1 lock=$2; shift 2
  echo "=== $stem starting $(date '+%F %T') ==="
  flock -w 7200 "$lock" "$@" >> "$R/results/$stem.log" 2>&1
  local rc=$?
  echo $rc > "$R/results/$stem.done"
  echo "=== $stem exit $rc $(date '+%F %T') ==="
  return $rc
}

step fsp4_build_$TAG /tmp/zk-build.lock \
  $CARGO build --release --offline -j 2 --manifest-path $R/hashline/Cargo.toml || exit 1
step fsp4_buildgpu_$TAG /tmp/zk-build.lock \
  $GENV $CARGO build --release --offline -j 2 --features gpu-cuda --manifest-path $R/hashline/Cargo.toml || exit 1
step fsp4_planeoracle_gpu_$TAG /tmp/zk-build.lock \
  $GENV $CARGO test --release --offline -j 2 --features gpu-cuda --manifest-path $R/hashline/Cargo.toml --lib plane || exit 1
step fsp4_planeoracle_cpu_$TAG /tmp/zk-build.lock \
  $CARGO test --release --offline -j 2 --manifest-path $R/hashline/Cargo.toml --lib plane || exit 1
step fsp4_floors_$TAG /tmp/zk-heavy.lock $R/results/fsp4_floors.sh "$SP"
step fsp4_chunkgate_$TAG /tmp/zk-heavy.lock $R/results/fsp4_planes_chunked_gate.sh "$SP"
step fsp4_ab_planes_gpu_$TAG /tmp/zk-heavy.lock $R/results/fsp4_ab_planes.sh "$SP" gpu 5
step fsp4_ab_planes_cpu_$TAG /tmp/zk-heavy.lock $R/results/fsp4_ab_planes.sh "$SP" cpu 5
echo "=== DRIVE DONE $(date '+%F %T') ==="
