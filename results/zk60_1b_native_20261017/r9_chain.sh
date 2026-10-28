#!/bin/bash
# NATIVE LANE R9 (DD, D30): (1) targeted check; (2) the seeded golden (check
# (a)) on the live tree; (3) the R9 CPU and GPU CLIs; (4) check (b): the R9
# CLI re-verifies the two R8 T128 receipts (no --dd), read-only against their
# published statements; (5) `--dd` at a geometry with no DD profile is
# refused by name; (6) the DD runs on the TinyLlama dg and 8B b7voc0 T128
# exports (prove -> verify --controls -> byte re-check, HL_PB_TIMING on);
# (7) the full suite; (8) the R9 freeze, only if all green, the tree did not
# move since (1) and the CLIs were built from it.
set -u
D=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
W=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b
H=$W/hashline
M=$H/Cargo.toml
C=/home/victor/.cargo/bin/cargo
O=$D/r9
F=/home/victor/IntelligenceRegulation/results/zk60_fidelity_parity_20261019/exports
LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
tree() { python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['tree_sha256'])" "$1"; }
pre() {  # $1 need, $2 class
  until out=$(python3 $G check --class ${2:-cpu} --need-gib $1 2>&1); echo "$out" | grep -q "OK to start now" || ! echo "$out" | sed 's/[^;]*is held//g' | grep -q "budget\|MemAvailable"; do sleep 30; done
}
run() {  # label class need cap maxsecs -- cmd...
  local L=$1 K=$2 N=$3 P=$4 S=$5; shift 6
  pre $N $K
  python3 $G run --class $K --need-gib $N --cap-gib $P --label $L --wait-secs 21600 --max-secs $S \
    --log $O/$L.log --done $O/$L.done --result-json $O/$L.guard.json -- "$@"
  local rc=$?; echo "[$(date -u +%H:%M:%S)] $L exit $rc"; return $rc
}
python3 -B $D/r5_manifest.py $O/manifest_check.json "sources at the start of the R9 chain"
run r9-check cpu 4 7 3600 -- $C test --release --offline --locked -j2 --manifest-path $M --lib -- --test-threads=4 \
  r9_tests trained_stack_tests trained_block_tests r6_tests r8_tests s24_tests s25_tests s33_tests pad::tests trained_statement review_e_ cs_port_tests || exit 1
run r9-golden cpu 7.5 10.5 3600 -- /usr/bin/env RAYON_NUM_THREADS=16 $C test --release --offline --locked -j2 --manifest-path $M --lib -- --ignored --test-threads=1 --nocapture r9_golden || exit 1
grep "R9-GOLDEN" $O/r9-golden.log
run r9-cli-build build 2.5 5 3600 -- $C build --release --offline --locked -j2 --manifest-path $M --example zk60_trained_block || exit 1
X=$O/zk60_trained_block.release.bin
cp $H/target/release/examples/zk60_trained_block $X
run r9-gpu-cli-build build 3 5 3600 -- /usr/bin/env CUDA_ROOT=/home/victor/cuda-root LD_LIBRARY_PATH=$LD CARGO_TARGET_DIR=$H/target-gpu \
  $C build --release --offline --locked -j2 --manifest-path $M --features gpu-cuda --example zk60_trained_block || exit 1
cp $H/target-gpu/release/examples/zk60_trained_block $O/zk60_trained_block.gpu.release.bin
sha256sum $X $O/zk60_trained_block.gpu.release.bin > $O/binaries.sha256
for spec in "tl $D/r8/verifier-exports/tinyllama_dg_rot1_T128 $D/r8/stack-tinyllama_dg_rot1_T128-ho00-cpu/run caf6ced22fbb87a94c1f571a96faf278815668996863146805c9d2eea76c9165 2.5" \
            "8b $D/r8/verifier-exports/llama3_8b_pg_rot1_b7voc0_T128 $D/r8/stack-llama3_8b_pg_rot1_b7voc0_T128-ho00-cpu/run 5585f5eed7a24a559ce76ddbd0413ddffd877637efb07d29bbd9408b4fc5a3b4 3"; do
  set -- $spec
  run r9-compat-$1 cpu $5 8 3600 -- /usr/bin/env RAYON_NUM_THREADS=16 $X stack-verify --export $2 --artifact $3 --expect-statement $4 || exit 1
done
# (5) --dd at a geometry with no DD profile: refused by name (exit 1), no run dir
rm -rf $O/dd-refusal-probe
$X stack-prove --export /home/victor/IntelligenceRegulation/results/zk60_8b_calibration_20261017/export/llama3_8b_pg_rot1_T32 --seq ho00 --out $O/dd-refusal-probe --dd > $O/dd-refusal.log 2>&1
echo "dd refusal probe exit $? (want 1); dir exists: $([ -e $O/dd-refusal-probe ] && echo yes || echo no)"
grep -o 'DD (D30) is registered only[^"]*' $O/dd-refusal.log | head -1
# (6) the DD runs
DD=1 VNEED=2.5 VCAP=8 $D/r9_stack.sh $F/tinyllama_dg_rot1_T128 ho00 8 10.5 4
echo "tinyllama dg T128 DD script exit $?"
DD=1 VNEED=3 VCAP=8 $D/r9_stack.sh $F/llama3_8b_pg_rot1_b7voc0_T128 ho00 8 10.5 0
echo "8b b7voc0 T128 DD script exit $?"
python3 -B $D/r5_manifest.py $O/manifest_suite.json "sources at the start of the R9 full suite"
run r9-suite cpu 4.5 8 5400 -- $C test --release --offline --locked -j2 --no-fail-fast --manifest-path $M -- --test-threads=8 || exit 1
T=$(date -u +%Y-%m-%dT%H:%M:%SZ)
python3 -B $D/r5_manifest.py $O/manifest_frozen_working.json "the working copy at the R9 freeze $T" $W
A=$(tree $O/manifest_frozen_working.json)
for m in manifest_check manifest_suite; do
  [ "$(tree $O/$m.json)" = "$A" ] || { echo "the tree moved ($m): no freeze"; exit 1; }
done
rsync -a --delete --exclude target --exclude target-gpu $W/ $O/frozen-tree/
python3 -B $D/r5_manifest.py $O/manifest_frozen.json "the R9 frozen review copy r9/frozen-tree/ ($T)" $O/frozen-tree
[ "$(tree $O/manifest_frozen.json)" = "$A" ] || { echo "the frozen copy differs from the working copy"; exit 1; }
{
  printf 'R9 tree frozen for review at %s\ntree sha256 %s\nmanifest %s\ncopy %s\n' "$T" "$A" "$O/manifest_frozen.json" "$O/frozen-tree/"
  printf 'CLIs r9/zk60_trained_block.release.bin and .gpu.release.bin (r9/binaries.sha256), built from this tree\n'
  printf 'R9 = R8 + DD, the per-row division dictionary, built to register entry D30 (conditions 1-6) and CHECK.md B-1..B-8, profile-gated: three NEW profiles (TinyLlama T128 ...-t128-trained-ddict/1, Llama-3-8B T128 ...-llama-3-8b-t128-ddict32/1, dev rung ...-rung-dd-t32-dev/1), selected by --dd; every other profile byte-identical (seeded goldens, R8 receipts verify, no 24th slot).\n'
  printf 'Restriction (refuses by name, changes no relation): a DD profile must have an unpadded dictionary - h_pad = q_heads, t_pad = T, cap a power of two, Dom::S and Dom::Dd at or above the row width (Shape::check_dd_geometry); B-3 is vacuous at the DD profiles.\n'
  printf 'cap = 32. n_col = |{0} U exp outputs| per layer of every current export (r9/r9_ncol.json): TinyLlama worst 24 (8/14/24 at e_s 3/2/1); Llama-3-8B b6/b7/b7voc0 worst 19 (6/11/19); older Llama-3-8B pg_rot1_T32 (e_s 1) exactly 32 (passes; a 33-slot table is refused by name, tested).\n'
  printf 'Key = the row Sum (D30 allows row id or Sum; CHECK.md S-4 option); TAG_DD = 141; dictionary slot SC_DD = 23 appended last (Standalone).\n'
  printf 'NOT a soundness or privacy acceptance: D30 requires an independent soundness review, the rank lemma / NL-1 / gate passes on captures, before any DD receipt is called sound or private. R8 (r8/frozen-tree/, tree 7f64276a...) stays frozen.\n'
} > $O/FROZEN.txt
diff -ruN -x target -x target-gpu -x results $D/r8/frozen-tree $O/frozen-tree > $O/r9-vs-r8.patch
echo "R9 frozen $T tree $A; patch $(grep -c '' $O/r9-vs-r8.patch) lines"
