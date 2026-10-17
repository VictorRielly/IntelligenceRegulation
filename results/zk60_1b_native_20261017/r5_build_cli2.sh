#!/bin/bash
# NATIVE LANE round 5 (evening): rebuild the two release CLIs from the R5
# tree WITH the review r3_6 fix (bounded segment reader), which landed after
# r5_build.sh r5b had compiled the first CPU CLI. Called once by r5_stack.sh
# (marker r5_cli2.done). Guarded build jobs; copies into r5/ with sha256.
set -u
D=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
H=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b/hashline
M=$H/Cargo.toml
C=/home/victor/.cargo/bin/cargo
K=${1:-cli2}
LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
python3 -B $D/r5_manifest.py $D/r5/manifest_$K.json "sources at the r5_build_cli2.sh $K CLI rebuild"
python3 $G run --class build --need-gib 2.5 --cap-gib 5 --label r5-$K-build --wait-secs 14400 --max-secs 3600 \
  --log $D/r5-$K-build.log --done $D/r5-$K-build.done --result-json $D/r5-$K-build.guard.json \
  -- $C build --release --offline --locked -j2 --manifest-path $M --example zk60_trained_block
rc=$?; echo "$K-build exit $rc"
[ $rc -eq 0 ] || exit $rc
cp $H/target/release/examples/zk60_trained_block $D/r5/zk60_trained_block.release.bin
python3 $G run --class build --need-gib 3 --cap-gib 5 --label r5-$K-gpu-build --wait-secs 14400 --max-secs 3600 \
  --log $D/r5-$K-gpu-build.log --done $D/r5-$K-gpu-build.done --result-json $D/r5-$K-gpu-build.guard.json \
  -- /usr/bin/env CUDA_ROOT=/home/victor/cuda-root LD_LIBRARY_PATH=$LD CARGO_TARGET_DIR=$H/target-gpu \
     $C build --release --offline --locked -j2 --manifest-path $M --features gpu-cuda --example zk60_trained_block
rc=$?; echo "$K-gpu-build exit $rc"
[ $rc -eq 0 ] || exit $rc
cp $H/target-gpu/release/examples/zk60_trained_block $D/r5/zk60_trained_block.gpu.release.bin
sha256sum $D/r5/zk60_trained_block.release.bin $D/r5/zk60_trained_block.gpu.release.bin > $D/r5/binaries.sha256
cat $D/r5/binaries.sha256
python3 -B $D/r5_manifest.py $D/r5/manifest_${K}_after.json "sources after the r5_build_cli2.sh $K CLI rebuild"
