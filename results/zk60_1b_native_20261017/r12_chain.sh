#!/bin/bash
# NATIVE LANE R12 (D38, Shieldstral): (1) targeted check (r12 tests + the
# regression set); (2) check (a): the seeded goldens of the four existing T128
# shapes (incl. DD) and the statement identities against the R9 recordings;
# (3) the heavy Shieldstral T128 blocks (non-DD, DD) with HL_PB_TIMING;
# (4) the R12 CPU and GPU CLIs; (5) check (b): the R12 CLI verifies the R8
# non-DD and the R9 DD T128 receipts read-only against their published
# statements; (6) `--dd` at a geometry with no DD profile is refused by name;
# (7) the full suite (hashline + the kernel crate); (8) the R12 freeze, only
# if all green, the tree did not move since (1) and the CLIs were built from it.
set -u
D=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
W=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b
H=$W/hashline
M=$H/Cargo.toml
K=$W/private-block-kernel-shaped/Cargo.toml
C=/home/victor/.cargo/bin/cargo
O=$D/r12
LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
tree() { python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['tree_sha256'])" "$1"; }
pre() {  # $1 need, $2 class
  until out=$(python3 $G check --class ${2:-cpu} --need-gib $1 2>&1); echo "$out" | grep -q "OK to start now" || ! echo "$out" | sed 's/[^;]*is held//g' | grep -q "budget\|MemAvailable"; do sleep 30; done
}
run() {  # label class need cap maxsecs -- cmd...
  local L=$1 K2=$2 N=$3 P=$4 S=$5; shift 6
  pre $N $K2
  python3 $G run --class $K2 --need-gib $N --cap-gib $P --label $L --wait-secs 21600 --max-secs $S \
    --log $O/$L.log --done $O/$L.done --result-json $O/$L.guard.json -- "$@"
  local rc=$?; echo "[$(date -u +%H:%M:%S)] $L exit $rc"; return $rc
}
python3 -B $D/r5_manifest.py $O/manifest_check.json "sources at the start of the R12 chain"
run r12-check cpu 4 7 3600 -- $C test --release --offline --locked -j2 --manifest-path $M --lib -- --test-threads=4 \
  r12_tests r9_tests trained_stack_tests trained_block_tests r6_tests r8_tests s24_tests s25_tests s33_tests pad::tests trained_statement review_e_ cs_port_tests parity dense_tests trained_calib_tests rung_tests grow_tests || exit 1
run r12-golden cpu 7.5 10.5 3600 -- /usr/bin/env RAYON_NUM_THREADS=16 $C test --release --offline --locked -j2 --manifest-path $M --lib -- --ignored --test-threads=1 --nocapture r12_golden || exit 1
grep "R12-GOLDEN" $O/r12-golden.log
run r12-heavy cpu 8 11 3600 -- /usr/bin/env HL_PB_TIMING=1 RAYON_NUM_THREADS=16 $C test --release --offline --locked -j2 --manifest-path $M --lib -- --ignored --test-threads=1 --nocapture f2_a_generic_dense_shieldstral || exit 1
grep "R12 F2\|PB-TIMING prove \[" $O/r12-heavy.log
run r12-cli-build build 2.5 5 3600 -- $C build --release --offline --locked -j2 --manifest-path $M --example zk60_trained_block || exit 1
X=$O/zk60_trained_block.release.bin
cp $H/target/release/examples/zk60_trained_block $X
run r12-gpu-cli-build build 3 5 3600 -- /usr/bin/env CUDA_ROOT=/home/victor/cuda-root LD_LIBRARY_PATH=$LD CARGO_TARGET_DIR=$H/target-gpu \
  $C build --release --offline --locked -j2 --manifest-path $M --features gpu-cuda --example zk60_trained_block || exit 1
cp $H/target-gpu/release/examples/zk60_trained_block $O/zk60_trained_block.gpu.release.bin
sha256sum $X $O/zk60_trained_block.gpu.release.bin > $O/binaries.sha256
# (5) check (b): R8 non-DD receipts and R9 DD receipts under the R12 CLI
for spec in "tl $D/r8/verifier-exports/tinyllama_dg_rot1_T128 $D/r8/stack-tinyllama_dg_rot1_T128-ho00-cpu/run caf6ced22fbb87a94c1f571a96faf278815668996863146805c9d2eea76c9165 2.5 x" \
            "8b $D/r8/verifier-exports/llama3_8b_pg_rot1_b7voc0_T128 $D/r8/stack-llama3_8b_pg_rot1_b7voc0_T128-ho00-cpu/run 5585f5eed7a24a559ce76ddbd0413ddffd877637efb07d29bbd9408b4fc5a3b4 3 x" \
            "tl-dd $D/r9/verifier-exports/tinyllama_dg_rot1_T128 $D/r9/stack-tinyllama_dg_rot1_T128-ho00-cpu-dd/run d57212761b29a8eab43d03af012a3b5bec7154455786275f4000502893d22e4b 2.5 --dd" \
            "8b-dd $D/r9/verifier-exports/llama3_8b_pg_rot1_b7voc0_T128 $D/r9/stack-llama3_8b_pg_rot1_b7voc0_T128-ho00-cpu-dd/run 4da580bdda8b9e4aef4ceb281e2b31e8008d99425d2601553b38f753b1492520 3 --dd"; do
  set -- $spec
  DDF=""; [ "$6" = "--dd" ] && DDF="--dd"
  run r12-compat-$1 cpu $5 8 3600 -- /usr/bin/env RAYON_NUM_THREADS=16 $X stack-verify --export $2 --artifact $3 --expect-statement $4 $DDF || exit 1
done
# (6) --dd at a geometry with no DD profile: refused by name (exit 1), no run dir
rm -rf $O/dd-refusal-probe
$X stack-prove --export /home/victor/IntelligenceRegulation/results/zk60_8b_calibration_20261017/export/llama3_8b_pg_rot1_T32 --seq ho00 --out $O/dd-refusal-probe --dd > $O/dd-refusal.log 2>&1
echo "dd refusal probe exit $? (want 1); dir exists: $([ -e $O/dd-refusal-probe ] && echo yes || echo no)"
grep -o 'DD (D30) is registered only[^"]*' $O/dd-refusal.log | head -1
python3 -B $D/r5_manifest.py $O/manifest_suite.json "sources at the start of the R12 full suite"
run r12-suite cpu 4.5 8 7200 -- $C test --release --offline --locked -j2 --no-fail-fast --manifest-path $M -- --test-threads=8 || exit 1
run r12-suite-kernel cpu 1 3 1800 -- $C test --release --offline --locked -j2 --manifest-path $K || exit 1
T=$(date -u +%Y-%m-%dT%H:%M:%SZ)
python3 -B $D/r5_manifest.py $O/manifest_frozen_working.json "the working copy at the R12 freeze $T" $W
A=$(tree $O/manifest_frozen_working.json)
for m in manifest_check manifest_suite; do
  [ "$(tree $O/$m.json)" = "$A" ] || { echo "the tree moved ($m): no freeze"; exit 1; }
done
rsync -a --delete --exclude target --exclude target-gpu $W/ $O/frozen-tree/
python3 -B $D/r5_manifest.py $O/manifest_frozen.json "the R12 frozen review copy r12/frozen-tree/ ($T)" $O/frozen-tree
[ "$(tree $O/manifest_frozen.json)" = "$A" ] || { echo "the frozen copy differs from the working copy"; exit 1; }
printf '%s\n%s\n' "$T" "$A" > $O/frozen.stamp
diff -ruN -x target -x target-gpu -x results $D/r9/frozen-tree $O/frozen-tree > $O/r12-vs-r9.patch
echo "R12 frozen $T tree $A; patch $(grep -c '' $O/r12-vs-r9.patch) lines"
