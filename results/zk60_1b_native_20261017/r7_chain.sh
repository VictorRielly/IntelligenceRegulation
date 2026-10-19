#!/bin/bash
# NATIVE LANE R7 (review r6 note N-r6-b): (1) the targeted release lib tests
# (the new N-r6-b test, the stack/block CLI tests, r6_tests, census); only if
# green: (2) the R7 CPU and GPU CLI builds; (3) the full release suite;
# (4) the R7 freeze, only if the suite is green, the tree did not move since
# the targeted check, and the CLIs were built from it. Every heavy leaf runs
# through the guard; budgets pre-checked outside the heavy lock.
set -u
D=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
W=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b
H=$W/hashline
M=$H/Cargo.toml
C=/home/victor/.cargo/bin/cargo
O=$D/r7
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
python3 -B $D/r5_manifest.py $O/manifest_check.json "sources at the start of the R7 targeted check"
run r7-check cpu 4 7 3600 -- $C test --release --offline --locked -j2 --manifest-path $M --lib -- --test-threads=4 \
  review_n_r6_b review_r5_3 trained_stack_tests trained_block_tests r6_tests trained_statement review_e_ s24_tests s25_tests cs_port_tests || exit 1
run r7-cli-build build 2.5 5 3600 -- $C build --release --offline --locked -j2 --manifest-path $M --example zk60_trained_block || exit 1
cp $H/target/release/examples/zk60_trained_block $O/zk60_trained_block.release.bin
run r7-gpu-cli-build build 3 5 3600 -- /usr/bin/env CUDA_ROOT=/home/victor/cuda-root LD_LIBRARY_PATH=$LD CARGO_TARGET_DIR=$H/target-gpu \
  $C build --release --offline --locked -j2 --manifest-path $M --features gpu-cuda --example zk60_trained_block || exit 1
cp $H/target-gpu/release/examples/zk60_trained_block $O/zk60_trained_block.gpu.release.bin
sha256sum $O/zk60_trained_block.release.bin $O/zk60_trained_block.gpu.release.bin > $O/binaries.sha256
python3 -B $D/r5_manifest.py $O/manifest_suite.json "sources at the start of the R7 full suite"
run r7-suite cpu 4.5 8 5400 -- $C test --release --offline --locked -j2 --no-fail-fast --manifest-path $M -- --test-threads=8 || exit 1
T=$(date -u +%Y-%m-%dT%H:%M:%SZ)
python3 -B $D/r5_manifest.py $O/manifest_frozen_working.json "the working copy at the R7 freeze $T" $W
A=$(tree $O/manifest_frozen_working.json)
for m in manifest_check manifest_suite; do
  [ "$(tree $O/$m.json)" = "$A" ] || { echo "the tree moved ($m): no freeze"; exit 1; }
done
rsync -a --delete --exclude target --exclude target-gpu $W/ $O/frozen-tree/
python3 -B $D/r5_manifest.py $O/manifest_frozen.json "the R7 frozen review copy r7/frozen-tree/ ($T)" $O/frozen-tree
[ "$(tree $O/manifest_frozen.json)" = "$A" ] || { echo "the frozen copy differs from the working copy"; exit 1; }
printf 'R7 tree frozen for review at %s\ntree sha256 %s\nmanifest %s\ncopy %s\nCLIs r7/zk60_trained_block.release.bin and .gpu.release.bin (r7/binaries.sha256), built from this tree\nR7 = R6 + review r6 note N-r6-b (stale statement.writing-<pid>); R6 (r6/frozen-tree/, tree 83f1fdcb...) stays frozen\n' "$T" "$A" "$O/manifest_frozen.json" "$O/frozen-tree/" > $O/FROZEN.txt
diff -ruN -x target -x target-gpu -x results $D/r6/frozen-tree $O/frozen-tree > $O/r7-vs-r6.patch
echo "R7 frozen $T tree $A; patch $(grep -c '' $O/r7-vs-r6.patch) lines"
