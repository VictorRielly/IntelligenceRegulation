#!/bin/bash
# [FSP-HOST] The device-versus-CPU oracles, all of them, on the GPU binary:
#   * gpu-probe's field probe (2^20 pairs incl. edge values),
#   * the blake3 row-count checks (322 row counts x 64 columns),
#   * the transform checks at seven shapes (device RS encoding == the CPU
#     encoder element for element, inv_rate 2, 4 and 8),
#   * the chunked-commit checks at fifteen shapes (streamed leaves == CPU
#     hash_columns AND the re-encoded opening columns == the CPU encoding
#     at 16 indices, at inverse rates 2, 4 and 8).
# Then the GPU-feature Rust test binaries.
# Copy of results/fsp2_oracles.sh re-pointed at /home/victor/wt-fsp-host.
# The cargo invocations here DO take /tmp/zk-build.lock themselves, so do
# NOT wrap this script in the build lock; the heavy lock is fine.
# Usage: fsp4_oracles.sh
set -u
R=/home/victor/wt-fsp-host
CARGO=/home/victor/.cargo/bin/cargo
CUDA_LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
GPU=$R/hashline/target-gpu/release/hashline
echo "=== gpu-probe oracles ==="; date '+%F %T'
nvidia-smi --query-gpu=memory.used --format=csv,noheader
HL_GPU=1 LD_LIBRARY_PATH=$CUDA_LD "$GPU" gpu-probe 2>&1 | grep -E 'gpu-probe:|GeForce|ERROR|mismatch'
# The DEVICE test binaries only. `HL_GPU=1` must not be exported over the
# whole suite: `zk60_attention_schedule` is a CPU gate that asserts HL_GPU
# is unset, and `cargo test` stops at the first failing target.
echo "=== GPU-feature cargo tests (device targets) ==="; date '+%F %T'
for T in zk60_gpu_commit zk60_gpu_cache; do
  echo "--- $T ---"
  CUDA_ROOT=/home/victor/cuda-root LD_LIBRARY_PATH=$CUDA_LD CARGO_TARGET_DIR=$R/hashline/target-gpu HL_GPU=1 HL_GPU_REQUIRED=1 \
    flock -w 1800 /tmp/zk-build.lock $CARGO test --release --offline -j 2 --features gpu-cuda --manifest-path $R/hashline/Cargo.toml --test $T 2>&1 \
    | grep -E '^test result|^error|panicked|FAILED|ZK60_CL4_SUMMARY'
done
# [FSP-HOST] ITEM (a)'s ORACLES. `hashline/src/bin/hashline.rs` is not this
# lane's file, so the rung could not be added to the `gpu-probe` command;
# both oracles are lib unit tests and neither needs a device:
#   * gpu::planes::tests    — the plane fill against prove_layer_v3's own
#                             buffer (every configuration),
#   * gpu::cuda::fsp4_plane_oracle — the staged bytes against the REAL
#                             pack_narrow at w = 1, over block-splitting
#                             ranges and in the chunked/staging-piece form
#                             (only under --features gpu-cuda).
echo "=== [FSP-HOST] item (a) plane-fill oracles (gpu-cuda lib tests) ==="; date '+%F %T'
CUDA_ROOT=/home/victor/cuda-root LD_LIBRARY_PATH=$CUDA_LD CARGO_TARGET_DIR=$R/hashline/target-gpu \
  flock -w 1800 /tmp/zk-build.lock $CARGO test --release --offline -j 2 --features gpu-cuda --manifest-path $R/hashline/Cargo.toml --lib plane 2>&1 \
  | grep -E '^test |^test result|^error|panicked|FAILED'
echo "=== [FSP-HOST] item (a) plane-fill oracles (CPU lib tests) ==="; date '+%F %T'
flock -w 1800 /tmp/zk-build.lock $CARGO test --release --offline -j 2 --manifest-path $R/hashline/Cargo.toml --lib plane 2>&1 \
  | grep -E '^test |^test result|^error|panicked|FAILED'
echo "=== ORACLES DONE ==="; date '+%F %T'
