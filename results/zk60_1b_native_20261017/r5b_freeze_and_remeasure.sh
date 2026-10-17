#!/bin/bash
# NATIVE LANE R5b: once `r5b-suite1` is green AND the working tree is still
# the one the suite compiled (manifest_r5b-suite1.json), FREEZE R5b (a source
# copy under r5b/frozen-tree/ with its sha256 manifest), build the R5b CLIs
# into r5b/, and re-measure with them: the Llama-3-8B T32 stack (speed-plan
# task-1 acceptance on R5b), the TinyLlama T32 stack (identity 9b71dfb0...),
# then the Llama-3-8B T128 trained stack (task 4 on R5b; pending independent
# review of the T128 profile), each with a fresh-process verify + controls
# from the verifier's copy, which promotes its statement.
set -u
D=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
W=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b
H=$W/hashline
C=/home/victor/.cargo/bin/cargo
LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
until [ -f $D/r5b_suite1.done ]; do sleep 20; done
SX=$(cat $D/r5b-suite1.done 2>/dev/null)
[ "$SX" = 0 ] || { echo "r5b-suite1 not green (guard exit $SX): no freeze"; exit 1; }
T=$(date -u +%Y-%m-%dT%H:%M:%SZ)
mkdir -p $D/r5b/frozen-tree
python3 -B $D/r5_manifest.py $D/r5b/manifest_frozen_working.json "the working copy at the R5b freeze $T" $W
A=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['tree_sha256'])" $D/r5b/manifest_frozen_working.json)
S=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['tree_sha256'])" $D/r5/manifest_r5b-suite1.json)
[ "$A" = "$S" ] || { echo "the tree moved after r5b-suite1 started ($A vs $S): no freeze"; exit 1; }
rsync -a --delete --exclude target --exclude target-gpu $W/ $D/r5b/frozen-tree/
python3 -B $D/r5_manifest.py $D/r5b/manifest_frozen.json "the R5b frozen review copy r5b/frozen-tree/ ($T)" $D/r5b/frozen-tree
B=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['tree_sha256'])" $D/r5b/manifest_frozen.json)
[ "$A" = "$B" ] || { echo "the frozen copy differs from the working copy"; exit 1; }
printf 'R5b tree frozen for review at %s\ntree sha256 %s\nmanifest %s\ncopy %s\n' "$T" "$A" "$D/r5b/manifest_frozen.json" "$D/r5b/frozen-tree/" > $D/r5b/FROZEN.txt
echo "R5b frozen $T tree $A"
# the R5b CLIs (CPU and GPU), into r5b/
python3 $G run --class build --need-gib 2.5 --cap-gib 5 --label r5b-cli-build --wait-secs 14400 --max-secs 3600 \
  --log $D/r5b/cli-build.log --done $D/r5b/cli-build.done --result-json $D/r5b/cli-build.guard.json \
  -- $C build --release --offline --locked -j2 --manifest-path $H/Cargo.toml --example zk60_trained_block || exit 1
cp $H/target/release/examples/zk60_trained_block $D/r5b/zk60_trained_block.release.bin
python3 $G run --class build --need-gib 3 --cap-gib 5 --label r5b-gpu-cli-build --wait-secs 14400 --max-secs 3600 \
  --log $D/r5b/gpu-cli-build.log --done $D/r5b/gpu-cli-build.done --result-json $D/r5b/gpu-cli-build.guard.json \
  -- /usr/bin/env CUDA_ROOT=/home/victor/cuda-root LD_LIBRARY_PATH=$LD CARGO_TARGET_DIR=$H/target-gpu \
     $C build --release --offline --locked -j2 --manifest-path $H/Cargo.toml --features gpu-cuda --example zk60_trained_block || exit 1
cp $H/target-gpu/release/examples/zk60_trained_block $D/r5b/zk60_trained_block.gpu.release.bin
sha256sum $D/r5b/zk60_trained_block.release.bin $D/r5b/zk60_trained_block.gpu.release.bin > $D/r5b/binaries.sha256
python3 -B $D/r5_manifest.py $D/r5b/manifest_cli_after.json "the working copy after the R5b CLI builds" $W
echo "R5b CLIs built $(date -u +%H:%M:%S)"
# the re-measurements (8B T32: witness cache 4 GiB keeps all 32 witnesses)
VNEED=2.5 VCAP=8 $D/r5b_stack.sh /home/victor/IntelligenceRegulation/results/zk60_8b_calibration_20261017/export/llama3_8b_pg_rot1_T32 ho00 6 9 4
echo "8B T32 done $(date -u +%H:%M:%S)"
VNEED=2.5 VCAP=5 $D/r5b_stack.sh /home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929/export/pg_rot1_b4_T32_cal128 ho00 4 7 4
echo "TinyLlama T32 done $(date -u +%H:%M:%S)"
