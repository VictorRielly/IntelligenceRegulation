#!/bin/bash
# NATIVE LANE round 5 (evening, after the 18:21 UTC reboot): guarded builds of
# the R5 tree: (1) the CPU release CLI (example zk60_trained_block, panic=abort
# release profile), (2) the release test binaries (--no-run; the suite then
# only runs them), (3) the GPU-feature release CLI (separate target dir).
# Copies the two CLIs into r5/ with their sha256.
# usage: r5_build.sh <tag>
set -u
D=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
H=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b/hashline
M=$H/Cargo.toml
C=/home/victor/.cargo/bin/cargo
LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
T=${1:-r5}
python3 -B $D/r5_manifest.py $D/r5/manifest_$T.json "sources at the start of r5_build.sh $T"
python3 $G run --class build --need-gib 2.5 --cap-gib 5 --label $T-cli-build --wait-secs 14400 --max-secs 3600 \
  --log $D/$T-cli-build.log --done $D/$T-cli-build.done --result-json $D/$T-cli-build.guard.json \
  -- $C build --release --offline --locked -j2 --manifest-path $M --example zk60_trained_block
rc=$?; echo "cli-build exit $rc"
[ $rc -eq 0 ] || exit $rc
cp $H/target/release/examples/zk60_trained_block $D/r5/zk60_trained_block.release.bin
python3 $G run --class build --need-gib 3 --cap-gib 6 --label $T-test-build --wait-secs 14400 --max-secs 3600 \
  --log $D/$T-test-build.log --done $D/$T-test-build.done --result-json $D/$T-test-build.guard.json \
  -- $C test --release --offline --locked -j2 --manifest-path $M --no-run
rc=$?; echo "test-build exit $rc"
[ $rc -eq 0 ] || exit $rc
python3 $G run --class build --need-gib 3 --cap-gib 5 --label $T-gpu-build --wait-secs 14400 --max-secs 3600 \
  --log $D/$T-gpu-build.log --done $D/$T-gpu-build.done --result-json $D/$T-gpu-build.guard.json \
  -- /usr/bin/env CUDA_ROOT=/home/victor/cuda-root LD_LIBRARY_PATH=$LD CARGO_TARGET_DIR=$H/target-gpu \
     $C build --release --offline --locked -j2 --manifest-path $M --features gpu-cuda --example zk60_trained_block
rc=$?; echo "gpu-build exit $rc"
[ $rc -eq 0 ] || exit $rc
cp $H/target-gpu/release/examples/zk60_trained_block $D/r5/zk60_trained_block.gpu.release.bin
sha256sum $D/r5/zk60_trained_block.release.bin $D/r5/zk60_trained_block.gpu.release.bin > $D/r5/binaries.sha256
cat $D/r5/binaries.sha256
