#!/bin/bash
# 2026-11-09, coordinator. Lane A28 (byte-preserving: the pruned forward transform and the two-pass column hash in
# gpu/metal.rs and metal_kernels.metal; seal-ahead in classify-serve, off by default; the app's pin and settings),
# merged into perf after the Lean lanes L26-L33: the check on the MERGED tree in the main checkout. It follows
# results/zk60_a27_app_20261107/check_a27merge.sh:
# - hashline's WHOLE lib suite, with the R13 loader fixtures named (exactly the 3 long-known failures expected);
# - zkp-core's suite;
# - the seeded Lean exports L9, L11, L13 and L17, each compared byte for byte with the committed corpora;
# - lane L29's test-only export on this tree and the Lean stage checker on it (the stage segments a classify run
#   writes must still be the ones the Lean stage verifiers accept);
# - the app's whole suite (the venv was rebuilt after the 2026-11-09 reboot at ~/zk60-artifacts/a28-tools/venv).
# One guarded job, class cpu. Scratch output goes outside the repository.
set -u
R=/Users/victorrielly/IntelligenceRegulation
O=$R/results/zk60_a28_app_20261107
M=$R/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
S=/Users/victorrielly/zk60-artifacts/lean-merge-fixtures/a28merge
FX=$R/results/zk60_1b_native_20261017/r13/loader-fixtures
L=$R/formal/ZK60Formal
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
C="/opt/homebrew/bin/cargo test --release --offline --locked -j 2 --manifest-path $M --lib"
P=$O/a28merge.progress
X=$O/a28merge
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
: > $P
say "start; HEAD $(git -C $R rev-parse --short HEAD)"
rm -rf $S; mkdir -p $S/l17 $S/l29
env HL_R13_LOADER_FIXTURES=$FX $C > ${X}_hashline_lib.log 2>&1; say "hashline whole lib suite rc=$? (the 3 known failures expected)"
grep -E "^test result" ${X}_hashline_lib.log >> $P
grep -E "^test .* FAILED$" ${X}_hashline_lib.log >> $P
/opt/homebrew/bin/cargo test --release --offline --locked -j 2 --manifest-path $R/ops/zkp-mvp/gpu-metal/zkp-core/Cargo.toml \
  > ${X}_zkpcore.log 2>&1; say "zkp-core suite rc=$?"
grep -E "^test result" ${X}_zkpcore.log | head -1 >> $P
env L9_OUT=$S $C lean_l9_export_the_w16r2_rung_block -- --test-threads 1 > ${X}_l9export.log 2>&1
cmp $S/corpus.txt $R/results/zk60_lean_l9_20261107/corpus.txt; say "L9 corpus byte-identical: cmp rc=$?"
env LEAN_L11_CORPUS=$S/l11.txt $C lean_l11_export > ${X}_l11export.log 2>&1
cmp $S/l11.txt $R/results/zk60_lean_l11_20261107/corpus.txt; say "L11 corpus byte-identical: cmp rc=$?"
env LEAN_L13_CORPUS=$S/l13.txt $C lean_l13_export > ${X}_l13export.log 2>&1
cmp $S/l13.txt $R/results/zk60_lean_l13_20261107/layout.txt; say "L13 layout byte-identical: cmp rc=$?"
env L17_OUT=$S/l17 HL_R13_LOADER_FIXTURES=$FX $C lean_l17_export -- --test-threads 1 > ${X}_l17export.log 2>&1
for f in block_corpus.txt slots_corpus.txt shape_corpus.txt; do
  cmp $S/l17/$f $R/results/zk60_lean_l17_20261107/$f; say "L17 $f byte-identical: cmp rc=$?"
done
( cd $S/l17 && shasum -a 256 fork_frame.bin open_corpus.txt ) > $S/l17.sha
grep -E "fork_frame.bin|open_corpus.txt" $R/results/zk60_lean_l17_20261107/large_files.sha256 > $S/l17.want
cmp $S/l17.sha $S/l17.want; say "L17 fork_frame.bin and open_corpus.txt sha256 as committed: cmp rc=$?"
rm -f $S/l17/open_corpus.txt
env LEAN_L29_CORPUS=$S/l29/corpus.txt LEAN_L29_SEG_IN=$S/l29/l29_seg_in.bin LEAN_L29_SEG_OUT=$S/l29/l29_seg_out.bin \
  $C lean_l29_export -- --nocapture > ${X}_l29export.log 2>&1; say "hashline lean_l29_export (test only) rc=$?"
ulimit -s 65520
$LAKE -d $R/formal env lean --run $L/StageVerifyExecCheck.lean $S/l29/corpus.txt $S/l29/l29_seg_in.bin $S/l29/l29_seg_out.bin \
  > ${X}_l29check.log 2>&1; say "StageVerifyExecCheck on this tree's fresh export rc=$?"
grep -E "^FAIL|^StageVerifyExecCheck" ${X}_l29check.log >> $P
/usr/bin/env PM_TINYLLAMA_TOKENIZER=$R/results/zk60_astra_20261026/app_decision_refresh_20261104/tokenizers/tokenizer.model \
  PYTHONPATH=$R/apps/proven-media PYTHONDONTWRITEBYTECODE=1 /Users/victorrielly/zk60-artifacts/a28-tools/venv/bin/python \
  -m unittest discover -s $R/apps/proven-media/tests > ${X}_app.log 2>&1; say "app suite rc=$?"
tail -3 ${X}_app.log >> $P
ls $R/ops/zkp-mvp/gpu-metal/results 2>/dev/null | sed 's/^/test-output directory left by the lib suite (untracked, to delete): /' >> $P
say "all done"
