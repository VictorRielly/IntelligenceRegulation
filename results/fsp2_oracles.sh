#!/bin/bash
# [FSP-L9] The device-versus-CPU oracles, all of them, on the GPU binary:
#   * gpu-probe's field probe (2^20 pairs incl. edge values),
#   * the blake3 row-count checks (322 row counts x 64 columns),
#   * the transform checks at seven shapes (device RS encoding == the CPU
#     encoder element for element, inv_rate 2, 4 and 8),
#   * the chunked-commit checks at fifteen shapes — streamed leaves ==
#     CPU hash_columns AND the RE-ENCODED OPENING COLUMNS == the CPU
#     encoding at 16 indices, at inverse rates 2, 4 and 8 (rb = 1, 2, 3:
#     all three zero-padding depths the pad kernel can see). That last one
#     is this lane's own oracle.
# Then the GPU-feature Rust test binaries (hiding chunked commit vs CPU at
# every rate, deferred openings, allocation-failure fallbacks).
# No build lock is taken here; wrap the whole script in the heavy lock.
# Usage: fsp2_oracles.sh
set -u
R=/home/victor/wt-fsp-l9
CARGO=/home/victor/.cargo/bin/cargo
CUDA_LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
GPU=$R/hashline/target-gpu/release/hashline
echo "=== gpu-probe oracles ==="; date '+%F %T'
nvidia-smi --query-gpu=memory.used --format=csv,noheader
HL_GPU=1 LD_LIBRARY_PATH=$CUDA_LD "$GPU" gpu-probe 2>&1 | grep -E 'gpu-probe:|GeForce|ERROR|mismatch'
# The DEVICE test binary only. `HL_GPU=1` must not be exported over the
# whole suite: `zk60_attention_schedule` is a CPU gate that asserts HL_GPU
# is unset, and `cargo test` stops at the first failing target, so a
# whole-suite run with HL_GPU set never reaches the device tests at all
# (seen on this lane's first attempt, results/fsp2_oracles_s3.log).
# The CPU suite is covered separately by results/fsp2_cputest.log.
echo "=== GPU-feature cargo tests (device targets) ==="; date '+%F %T'
for T in zk60_gpu_commit zk60_gpu_cache; do
  echo "--- $T ---"
  CUDA_ROOT=/home/victor/cuda-root LD_LIBRARY_PATH=$CUDA_LD CARGO_TARGET_DIR=$R/hashline/target-gpu HL_GPU=1 HL_GPU_REQUIRED=1 \
    flock -w 900 /tmp/zk-build.lock $CARGO test --release --offline -j 2 --features gpu-cuda --manifest-path $R/hashline/Cargo.toml --test $T 2>&1 \
    | grep -E '^test result|^error|panicked|FAILED|ZK60_CL4_SUMMARY'
done
echo "=== ORACLES DONE ==="; date '+%F %T'
