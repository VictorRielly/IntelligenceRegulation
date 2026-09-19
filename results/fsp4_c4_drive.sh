#!/bin/bash
# [FSP-HOST] C3 + C4 in one detached driver (the no-hangup protocol): the
# builds, item (a)'s two byte-image oracles, the full oracle script, the
# twelve byte gates and both A/Bs, in order, each step under the RIGHT lock
# and never two at once.
#
# Locks: the cargo steps take /tmp/zk-build.lock and NOTHING else; the run
# steps take /tmp/zk-heavy.lock and nothing else. The driver never holds one
# while waiting for the other — that is exactly the jam this lane walked
# into at 12:10 (a script holding the heavy lock while blocked on the build
# lock). `results/fsp4_oracles.sh` takes the build lock itself, so it is
# wrapped in the heavy lock only.
#
# Every step appends to its own log and writes <log-stem>.done with the exit
# code, so any later session can see what finished.
# Usage: fsp4_c4_drive.sh <tag>
set -u
R=/home/victor/wt-fsp-host
TAG="${1:?tag required}"
SP=/tmp/claude-1000/-home-victor-IntelligenceRegulation/e277dbc7-36bc-4ae1-8184-db91a6d569e4/scratchpad/fsp4$TAG
CARGO=/home/victor/.cargo/bin/cargo
CUDA_LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
mkdir -p "$SP"

step () { # step <log-stem> <lock> <cmd...>
  local stem=$1 lock=$2; shift 2
  echo "=== $stem starting $(date '+%F %T') ==="
  flock -w 7200 "$lock" "$@" >> "$R/results/$stem.log" 2>&1
  local rc=$?
  echo $rc > "$R/results/$stem.done"
  echo "=== $stem exit $rc $(date '+%F %T') ==="
  return $rc
}

# ---- the builds -------------------------------------------------------
step fsp4_build_$TAG /tmp/zk-build.lock \
  $CARGO build --release --offline -j 2 --manifest-path $R/hashline/Cargo.toml || exit 1
# (the GPU env goes through `env` so it cannot leak into a later step)
GENV="env CUDA_ROOT=/home/victor/cuda-root LD_LIBRARY_PATH=$CUDA_LD CARGO_TARGET_DIR=$R/hashline/target-gpu"
step fsp4_buildgpu_$TAG /tmp/zk-build.lock \
  $GENV $CARGO build --release --offline -j 2 --features gpu-cuda --manifest-path $R/hashline/Cargo.toml || exit 1

# ---- item (a)'s byte-image oracles (no device needed) -----------------
step fsp4_planeoracle_gpu_$TAG /tmp/zk-build.lock \
  $GENV $CARGO test --release --offline -j 2 --features gpu-cuda --manifest-path $R/hashline/Cargo.toml --lib plane || exit 1
step fsp4_planeoracle_cpu_$TAG /tmp/zk-build.lock \
  $CARGO test --release --offline -j 2 --manifest-path $R/hashline/Cargo.toml --lib plane || exit 1

# ---- the full CPU suite ------------------------------------------------
step fsp4_cputest_$TAG /tmp/zk-heavy.lock \
  $CARGO test --release --offline -j 2 --manifest-path $R/hashline/Cargo.toml

# ---- the twelve byte gates --------------------------------------------
step fsp4_floors_$TAG /tmp/zk-heavy.lock $R/results/fsp4_floors.sh "$SP"

# ---- the device oracles (gpu-probe + the GPU test binaries) -----------
step fsp4_oracles_$TAG /tmp/zk-heavy.lock $R/results/fsp4_oracles.sh

# ---- the A/B, GPU binary then CPU binary ------------------------------
step fsp4_ab_planes_gpu_$TAG /tmp/zk-heavy.lock $R/results/fsp4_ab_planes.sh "$SP" gpu 5
step fsp4_ab_planes_cpu_$TAG /tmp/zk-heavy.lock $R/results/fsp4_ab_planes.sh "$SP" cpu 5

echo "=== DRIVE DONE $(date '+%F %T') ==="
