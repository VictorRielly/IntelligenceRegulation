#!/bin/bash
# NATIVE LANE R8 (every export-chosen calibration constant per layer):
# (1) the targeted release lib tests; only if green: (2) the R8 CPU and GPU
# CLI builds; (3) compatibility: the R8 CLI re-verifies, read-only against
# their existing statement/ (byte check), the R6 b7 T128 per-layer-sh_s run
# (pin 97c4acda...: identity AND stage schedule unchanged for sh_s-only),
# the 8B T32 and TinyLlama T32 run-wide compat runs (259dad7c..., 9b71dfb0...);
# (4) the full release suite; (5) the R8 freeze, only if all green, the tree
# did not move since the check, and the CLIs were built from it.
# usage: r8_chain.sh [skip-check]
set -u
D=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
W=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b
H=$W/hashline
M=$H/Cargo.toml
C=/home/victor/.cargo/bin/cargo
O=$D/r8
LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
tree() { python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['tree_sha256'])" "$1"; }
pre() {  # $1 need, $2 class
  until out=$(python3 $G check --class ${2:-cpu} --need-gib $1 2>&1); echo "$out" | grep -q "OK to start now" || ! echo "$out" | sed 's/[^;]*is held//g' | grep -q "budget\|MemAvailable"; do sleep 30; done
}
run() {  # label class need cap maxsecs -- cmd...
  local L=$1 K=$2 N=$3 P=$4 S=$5; shift 6
  pre $N $K
  python3 $G run --class $K --need-gib $N --cap-gib $P --label $L --wait-secs 14400 --max-secs $S \
    --log $O/$L.log --done $O/$L.done --result-json $O/$L.guard.json -- "$@"
  local rc=$?; echo "[$(date -u +%H:%M:%S)] $L exit $rc"; return $rc
}
python3 -B $D/r5_manifest.py $O/manifest_check.json "sources at the start of the R8 targeted check"
run r8-check cpu 4 7 3600 -- $C test --release --offline --locked -j2 --manifest-path $M --lib -- --test-threads=4 \
  r8_tests r6_tests trained_stack_tests trained_block_tests trained_statement trained_calib_tests review_e_ s24_tests s25_tests cs_port_tests review_d24 r4_tests || exit 1
[ "${1:-}" = check-only ] && exit 0
run r8-cli-build build 2.5 5 3600 -- $C build --release --offline --locked -j2 --manifest-path $M --example zk60_trained_block || exit 1
X=$O/zk60_trained_block.release.bin
cp $H/target/release/examples/zk60_trained_block $X
run r8-gpu-cli-build build 3 5 3600 -- /usr/bin/env CUDA_ROOT=/home/victor/cuda-root LD_LIBRARY_PATH=$LD CARGO_TARGET_DIR=$H/target-gpu \
  $C build --release --offline --locked -j2 --manifest-path $M --features gpu-cuda --example zk60_trained_block || exit 1
cp $H/target-gpu/release/examples/zk60_trained_block $O/zk60_trained_block.gpu.release.bin
sha256sum $X $O/zk60_trained_block.gpu.release.bin > $O/binaries.sha256
for spec in "b7 $D/r6/verifier-exports/llama3_8b_pg_rot1_b7_T128 $D/r6/stack-llama3_8b_pg_rot1_b7_T128-ho00-cpu/run 97c4acda9da994c11790c2c8ec93b44beecb21501686b7e25965d2c18f970566 3" \
            "8b-t32 $D/r5b/verifier-exports/llama3_8b_pg_rot1_T32 $D/r6/compat-llama3_8b_pg_rot1_T32/run 259dad7cb2c9739e44cfdf5c27c4c87090458cf330e9d39b592221094ae3537f 2.5" \
            "tl-t32 $D/r5b/verifier-exports/pg_rot1_b4_T32_cal128 $D/r6/compat-pg_rot1_b4_T32_cal128/run 9b71dfb0a2b4608d4a60d3bc4310a59573b6fcdf4a638f53a246c17b2cf24868 2.5"; do
  set -- $spec
  run r8-compat-$1 cpu $5 8 3600 -- /usr/bin/env RAYON_NUM_THREADS=16 $X stack-verify --export $2 --artifact $3 --expect-statement $4 || exit 1
done
python3 -B $D/r5_manifest.py $O/manifest_suite.json "sources at the start of the R8 full suite"
run r8-suite cpu 4.5 8 5400 -- $C test --release --offline --locked -j2 --no-fail-fast --manifest-path $M -- --test-threads=8 || exit 1
T=$(date -u +%Y-%m-%dT%H:%M:%SZ)
python3 -B $D/r5_manifest.py $O/manifest_frozen_working.json "the working copy at the R8 freeze $T" $W
A=$(tree $O/manifest_frozen_working.json)
for m in manifest_check manifest_suite; do
  [ "$(tree $O/$m.json)" = "$A" ] || { echo "the tree moved ($m): no freeze"; exit 1; }
done
rsync -a --delete --exclude target --exclude target-gpu $W/ $O/frozen-tree/
python3 -B $D/r5_manifest.py $O/manifest_frozen.json "the R8 frozen review copy r8/frozen-tree/ ($T)" $O/frozen-tree
[ "$(tree $O/manifest_frozen.json)" = "$A" ] || { echo "the frozen copy differs from the working copy"; exit 1; }
printf 'R8 tree frozen for review at %s\ntree sha256 %s\nmanifest %s\ncopy %s\nCLIs r8/zk60_trained_block.release.bin and .gpu.release.bin (r8/binaries.sha256), built from this tree\nR8 = R7 + every export-chosen calibration constant per layer (D32); R7 (r7/frozen-tree/, tree 36a8aed1...) stays frozen\n' "$T" "$A" "$O/manifest_frozen.json" "$O/frozen-tree/" > $O/FROZEN.txt
diff -ruN -x target -x target-gpu -x results $D/r7/frozen-tree $O/frozen-tree > $O/r8-vs-r7.patch
echo "R8 frozen $T tree $A; patch $(grep -c '' $O/r8-vs-r7.patch) lines"
