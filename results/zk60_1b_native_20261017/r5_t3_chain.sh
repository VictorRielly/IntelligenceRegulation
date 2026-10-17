#!/bin/bash
# NATIVE LANE, speed plan task 3 (2026-10-17 evening), on the working copy
# AFTER the R5 freeze (the 8B T64 / T128 profiles + ladder8b_tests applied
# 20:11 UTC): (1) the guarded release LIB suite (every lib test, including
# the registry / census tests the new profiles enter), (2) the generic 8B
# block at T64 and T128 on the CPU (with every control, fresh verify),
# (3) the GPU-feature test build, (4) the GPU arm at T64 and T128 (one GPU
# pass per guarded command; fresh verify by the CPU test binary).
set -u
D=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
H=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b/hashline
M=$H/Cargo.toml
C=/home/victor/.cargo/bin/cargo
LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
python3 -B $D/r5_manifest.py $D/r5/manifest_t3.json "the working copy at the task-3 chain start (R5 frozen tree + 8B T64/T128 profiles + ladder8b_tests)"
python3 $G run --class cpu --need-gib 4.5 --cap-gib 8 --label t3-lib --wait-secs 14400 --max-secs 5400 \
  --log $D/t3-lib.log --done $D/t3-lib.done --result-json $D/t3-lib.guard.json \
  -- $C test --release --offline --locked -j2 --manifest-path $M --lib -- --test-threads=8
echo "t3-lib exit $(cat $D/t3-lib.done) $(date -u +%H:%M:%S)"
$D/r5_ladder.sh 64 cpu 4.5 8
echo "ladder T64 cpu done $(date -u +%H:%M:%S)"
VNEED=3 VCAP=6 $D/r5_ladder.sh 128 cpu 7 10
echo "ladder T128 cpu done $(date -u +%H:%M:%S)"
python3 $G run --class build --need-gib 3 --cap-gib 6 --label t3-gpu-testbuild --wait-secs 14400 --max-secs 3600 \
  --log $D/t3-gpu-testbuild.log --done $D/t3-gpu-testbuild.done --result-json $D/t3-gpu-testbuild.guard.json \
  -- /usr/bin/env CUDA_ROOT=/home/victor/cuda-root LD_LIBRARY_PATH=$LD CARGO_TARGET_DIR=$H/target-gpu \
     $C test --release --offline --locked -j2 --manifest-path $M --features gpu-cuda --lib --no-run
echo "gpu test build exit $(cat $D/t3-gpu-testbuild.done) $(date -u +%H:%M:%S)"
$D/r5_ladder.sh 64 gpu 4 7
echo "ladder T64 gpu done $(date -u +%H:%M:%S)"
$D/r5_ladder.sh 128 gpu 6 9
echo "ladder T128 gpu done $(date -u +%H:%M:%S)"
