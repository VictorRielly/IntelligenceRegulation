#!/bin/bash
# D63 step L17 (the block-level results at R13, the media app's classifier blocks), merged into perf after L9-L16 and A24:
# the check on the MERGED tree in the main checkout. TEST_ONLY_FILES is now 87.
# 1. The seeded test-only export, run into scratch: its four small corpora are compared byte for byte with the committed
#    ones, and its three large files (kept outside the repo) by sha256 with large_files.sha256.
# 2. hashline: s25, hash_domain and r19b.
# 3. L17's five modules built one at a time, then the full Lean build.
# 4. The L17, L16 and L13 axiom audits, and the source scan of the eight L17 files.
# 5. CheckR13Slots, CheckR13Block and CheckR13Open (the reduced corpus), each with its negative control.
# 6. Regressions: ExecBlockCheck, L11Check, L6Check, L5Check and the fixture L1 check.
# One guarded job, class cpu.
set -u
R=/Users/victorrielly/IntelligenceRegulation
O=$R/results/zk60_lean_l17_20261107
O16=$R/results/zk60_lean_l16_20261107
O13=$R/results/zk60_lean_l13_20261107
O9=$R/results/zk60_lean_l9_20261107
O11=$R/results/zk60_lean_l11_20261107
O6=$R/results/zk60_lean_l6_20261106
O5=$R/results/zk60_lean_l5_20261106
R1=$R/results/zk60_lean_l1l2_20261106
V=$R/ops/zkp-mvp/gpu-metal/hashline/src/private_block/r13_vectors
L=$R/formal/ZK60Formal
M=$R/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
S=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/l17merge
F=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/l9merge/fork_frame.bin
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
C="/opt/homebrew/bin/cargo test --release --offline --locked -j 2 --manifest-path $M --lib"
P=$O/l17merge.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
rm -rf $S; mkdir -p $S/out
env L17_OUT=$S/out HL_R13_LOADER_FIXTURES=$R/results/zk60_1b_native_20261017/r13/loader-fixtures \
  $C lean_l17_export -- --nocapture --test-threads 1 > $O/l17merge_export.log 2>&1; say "hashline lean_l17_export rc=$?"
grep -E "^test result" $O/l17merge_export.log >> $P
for f in block_corpus.txt slots_corpus.txt segment_corpus.txt shape_corpus.txt; do
  cmp $S/out/$f $O/$f; say "regenerated $f equals the committed one: cmp rc=$?"
done
( cd $S/out && shasum -a 256 fork_frame.bin segment.bin open_corpus.txt ) > $S/large.sha256
cmp $S/large.sha256 $O/large_files.sha256; say "the three large files' sha256 equal large_files.sha256: cmp rc=$?"
for f in s25_tests hash_domain r19b; do
  $C $f > $O/l17merge_$f.log 2>&1; say "hashline $f rc=$?"
  grep -E "^test result" $O/l17merge_$f.log >> $P
done
for m in ZK60Formal.ExecBlockR13 ZK60Formal.SlotR13 ZK60Formal.OpeningR13 ZK60Formal.LayoutR13 ZK60Formal.ShapeR13; do
  $LAKE -d $R/formal build $m > $O/l17merge_prebuild.log 2>&1; say "lake build $m rc=$?"
done
$LAKE -d $R/formal build > $O/l17merge_lake.log 2>&1; say "lake build (full) rc=$?"
tail -2 $O/l17merge_lake.log >> $P
grep -ciE "warning|sorry" $O/l17merge_lake.log | sed 's/^/lines naming a warning or sorry in the build log: /' >> $P
for A in $O/axioms_l17.lean $O16/axioms_l16.lean $O13/axioms_l13.lean; do
  b=$(basename $A .lean)
  $LAKE -d $R/formal env lean $A > $O/l17merge_$b.log 2>&1; say "axiom audit $b rc=$?"
  grep -cE "sorryAx|ofReduceBool" $O/l17merge_$b.log | sed 's/^/sorryAx or ofReduceBool mentions: /' >> $P
  grep -oE "axioms: \[[^]]*\]" $O/l17merge_$b.log | sort | uniq -c >> $P
done
grep -n -E '\bsorry\b|\baxiom\b|native_decide|admit|maxRecDepth|maxHeartbeats|implemented_by|@\[extern|bv_decide|ofReduceBool' \
  $L/ExecBlockR13.lean $L/SlotR13.lean $L/OpeningR13.lean $L/LayoutR13.lean $L/ShapeR13.lean $L/CheckR13Block.lean \
  $L/CheckR13Slots.lean $L/CheckR13Open.lean > $O/l17merge_scan.log; say "source scan hits (grep rc 1 = none): rc=$?"
$LAKE -d $R/formal env lean --run $L/CheckR13Slots.lean $O/slots_corpus.txt > $O/l17merge_slots.log 2>&1; say "CheckR13Slots rc=$?"
tail -1 $O/l17merge_slots.log >> $P
python3 -I $O/mutate_slots.py $O/slots_corpus.txt $S/slots_neg.txt
$LAKE -d $R/formal env lean --run $L/CheckR13Slots.lean $S/slots_neg.txt > $O/l17merge_slots_neg.log 2>&1
say "CheckR13Slots negative control (7 changes)"; tail -1 $O/l17merge_slots_neg.log >> $P
ulimit -s 65520
$LAKE -d $R/formal env lean --run $L/CheckR13Block.lean $O/block_corpus.txt $S/out/fork_frame.bin $O/segment_corpus.txt \
  $S/out/segment.bin > $O/l17merge_block.log 2>&1; say "CheckR13Block rc=$?"
tail -1 $O/l17merge_block.log >> $P
python3 -I $O/mutate_block.py $O/block_corpus.txt $S/block_neg.txt $O/segment_corpus.txt $S/segment_neg.txt
$LAKE -d $R/formal env lean --run $L/CheckR13Block.lean $S/block_neg.txt $S/out/fork_frame.bin $S/segment_neg.txt \
  $S/out/segment.bin > $O/l17merge_block_neg.log 2>&1
say "CheckR13Block negative control (8 changes)"; tail -1 $O/l17merge_block_neg.log >> $P
python3 -I $O/mksmall.py $S/out/open_corpus.txt $S/open_small.txt
$LAKE -d $R/formal env lean --run $L/CheckR13Open.lean $S/open_small.txt > $O/l17merge_open.log 2>&1; say "CheckR13Open (reduced) rc=$?"
tail -1 $O/l17merge_open.log >> $P
python3 -I $O/negctl_open.py $S/open_small.txt $S/open_neg.txt
$LAKE -d $R/formal env lean --run $L/CheckR13Open.lean $S/open_neg.txt > $O/l17merge_open_neg.log 2>&1
say "CheckR13Open negative control (8 changes)"; tail -1 $O/l17merge_open_neg.log >> $P
$LAKE -d $R/formal env lean --run $L/ExecBlockCheck.lean $O9/corpus.txt $F > $O/l17merge_l9check.log 2>&1
say "ExecBlockCheck regression rc=$?"; tail -1 $O/l17merge_l9check.log >> $P
$LAKE -d $R/formal env lean --run $L/L11Check.lean $O11/corpus.txt > $O/l17merge_l11check.log 2>&1; say "L11Check rc=$?"
tail -1 $O/l17merge_l11check.log >> $P
$LAKE -d $R/formal env lean --run $L/L6Check.lean $O6/corpus.txt > $O/l17merge_l6check.log 2>&1; say "L6Check rc=$?"
tail -1 $O/l17merge_l6check.log >> $P
$LAKE -d $R/formal env lean --run $L/L5Check.lean $O5/corpus.txt > $O/l17merge_l5check.log 2>&1; say "L5Check rc=$?"
tail -1 $O/l17merge_l5check.log >> $P
$LAKE -d $R/formal env lean --run $L/L1Check.lean $V/block_fixture_t32.tsv \
  $V/block_trace_low_h24_t32.tsv $V/block_trace_low_t32.tsv $R1/rust_fixture_trace.tsv $V/r13_requant_vectors.tsv \
  > $O/l17merge_l1check.log 2>&1; say "fixture L1 check rc=$?"
tail -1 $O/l17merge_l1check.log >> $P
rm -f $S/out/open_corpus.txt
say "all done (the 139.6 MB opening corpus removed from scratch)"
