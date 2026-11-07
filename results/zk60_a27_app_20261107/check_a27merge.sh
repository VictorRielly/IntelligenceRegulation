#!/bin/bash
# Lane A27 (byte-preserving GPU kernel cuts: metal.rs, metal_kernels.metal, metal_slot.rs), merged into perf after A26 and the Lean lanes
# verify branch, the classifier's run and server), merged into perf after the Lean lanes L9-L17: the check on the MERGED
# tree in the main checkout. A26 touches shared code (zkp-core's PCS verifier, argument.rs, witness.rs), so this runs:
# - hashline's WHOLE lib suite, with the R13 loader fixtures named (A26 and A23: exactly 3 known failures);
# - zkp-core's suite;
# - the seeded Lean exports L9, L11, L13 and L17 (its seeded records), each compared byte for byte with the committed
#   corpora;
# - the app's whole suite.
# One guarded job, class cpu.
set -u
R=/Users/victorrielly/IntelligenceRegulation
O=$R/results/zk60_a27_app_20261107
M=$R/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
S=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/a27merge
FX=$R/results/zk60_1b_native_20261017/r13/loader-fixtures
C="/opt/homebrew/bin/cargo test --release --offline --locked -j 2 --manifest-path $M --lib"
P=$O/a27merge.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
rm -rf $S; mkdir -p $S/l17
env HL_R13_LOADER_FIXTURES=$FX $C > $O/a27merge_hashline_lib.log 2>&1; say "hashline whole lib suite rc=$? (3 known A23 failures expected)"
grep -E "^test result" $O/a27merge_hashline_lib.log >> $P
grep -E "^test .* FAILED$" $O/a27merge_hashline_lib.log >> $P
/opt/homebrew/bin/cargo test --release --offline --locked -j 2 --manifest-path $R/ops/zkp-mvp/gpu-metal/zkp-core/Cargo.toml \
  > $O/a27merge_zkpcore.log 2>&1; say "zkp-core suite rc=$?"
grep -E "^test result" $O/a27merge_zkpcore.log | head -1 >> $P
env L9_OUT=$S $C lean_l9_export_the_w16r2_rung_block -- --test-threads 1 > $O/a27merge_l9export.log 2>&1
cmp $S/corpus.txt $R/results/zk60_lean_l9_20261107/corpus.txt; say "L9 corpus byte-identical: cmp rc=$?"
env LEAN_L11_CORPUS=$S/l11.txt $C lean_l11_export > $O/a27merge_l11export.log 2>&1
cmp $S/l11.txt $R/results/zk60_lean_l11_20261107/corpus.txt; say "L11 corpus byte-identical: cmp rc=$?"
env LEAN_L13_CORPUS=$S/l13.txt $C lean_l13_export > $O/a27merge_l13export.log 2>&1
cmp $S/l13.txt $R/results/zk60_lean_l13_20261107/layout.txt; say "L13 layout byte-identical: cmp rc=$?"
env L17_OUT=$S/l17 HL_R13_LOADER_FIXTURES=$FX $C lean_l17_export -- --test-threads 1 > $O/a27merge_l17export.log 2>&1
for f in block_corpus.txt slots_corpus.txt shape_corpus.txt; do
  cmp $S/l17/$f $R/results/zk60_lean_l17_20261107/$f; say "L17 $f byte-identical: cmp rc=$?"
done
( cd $S/l17 && shasum -a 256 fork_frame.bin open_corpus.txt ) > $S/l17.sha
grep -E "fork_frame.bin|open_corpus.txt" $R/results/zk60_lean_l17_20261107/large_files.sha256 > $S/l17.want
cmp $S/l17.sha $S/l17.want; say "L17 fork_frame.bin and open_corpus.txt sha256 as committed: cmp rc=$?"
rm -f $S/l17/open_corpus.txt
/usr/bin/env PM_TINYLLAMA_TOKENIZER=$R/results/zk60_astra_20261026/app_decision_refresh_20261104/tokenizers/tokenizer.model \
  PYTHONPATH=$R/apps/proven-media PYTHONDONTWRITEBYTECODE=1 /private/tmp/zk60-astra-app-refresh-20261104-venv/bin/python \
  -m unittest discover -s $R/apps/proven-media/tests > $O/a27merge_app.log 2>&1; say "app suite rc=$?"
tail -3 $O/a27merge_app.log >> $P
say "all done"
