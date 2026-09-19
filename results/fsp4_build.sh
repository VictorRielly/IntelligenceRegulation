#!/bin/bash
# [FSP-HOST] Build both hashline binaries in this lane's worktree, under the
# shared build lock, offline, -j 2. CPU binary -> hashline/target/release,
# GPU binary -> hashline/target-gpu/release (lane AO's split, so the two
# arms of every byte gate are two real binaries).
# Copy of results/fsp2_build.sh re-pointed at /home/victor/wt-fsp-host.
set -u
R=/home/victor/wt-fsp-host
CARGO=/home/victor/.cargo/bin/cargo
CUDA_LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
echo "=== CPU build ==="; date '+%F %T'
flock -w 1800 /tmp/zk-build.lock $CARGO build --release --offline -j 2 --manifest-path $R/hashline/Cargo.toml || { echo "FAILURE: CPU build"; exit 1; }
echo "=== GPU build ==="; date '+%F %T'
CUDA_ROOT=/home/victor/cuda-root LD_LIBRARY_PATH=$CUDA_LD CARGO_TARGET_DIR=$R/hashline/target-gpu \
  flock -w 1800 /tmp/zk-build.lock $CARGO build --release --offline -j 2 --features gpu-cuda --manifest-path $R/hashline/Cargo.toml \
  || { echo "FAILURE: GPU build"; exit 1; }
echo "=== BUILDS OK ==="; date '+%F %T'
