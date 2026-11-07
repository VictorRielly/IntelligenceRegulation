#!/bin/bash
# D63 step L13 (the W16R2 slot builders, their evaluation, the layout facts, per-slot soundness), merged into perf after
# L9, L10, L11, L12, L15 and A24: the check on the MERGED tree in the main checkout. TEST_ONLY_FILES is now 86, and
# w16r2_tests.rs declares the L9, L10, L11 and L13 exports. The test-only export regenerates layout.txt into scratch
# (cmp with the committed one); hashline s25, hash_domain and r19b; L13's five modules built one at a time (a parallel
# first build of them exceeded the cap in the lane), then the full build; the L13, L15, L10, L12, L9 and L11 axiom
# audits; the source scan of the L13 files; SlotW16BuildCheck and its negative control (exactly 7 failed); and as
# regressions ExecBlockCheck, L11Check, L6Check, L5Check and the fixture L1 check. One guarded job, class cpu.
set -u
R=/Users/victorrielly/IntelligenceRegulation
O=$R/results/zk60_lean_l13_20261107
O15=$R/results/zk60_lean_l15_20261107
O10=$R/results/zk60_lean_l10_20261107
O12=$R/results/zk60_lean_l12_20261107
O9=$R/results/zk60_lean_l9_20261107
O11=$R/results/zk60_lean_l11_20261107
O6=$R/results/zk60_lean_l6_20261106
O5=$R/results/zk60_lean_l5_20261106
R1=$R/results/zk60_lean_l1l2_20261106
V=$R/ops/zkp-mvp/gpu-metal/hashline/src/private_block/r13_vectors
L=$R/formal/ZK60Formal
M=$R/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
S=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/l13merge
F=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/l9merge/fork_frame.bin
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
C="/opt/homebrew/bin/cargo test --release --offline --locked -j 2 --manifest-path $M --lib"
P=$O/l13merge.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
rm -rf $S; mkdir -p $S
env LEAN_L13_CORPUS=$S/layout.txt $C lean_l13_export -- --nocapture > $O/l13merge_export.log 2>&1
say "hashline lean_l13_export (test only) rc=$?"
grep -E "^test result" $O/l13merge_export.log >> $P
cmp $S/layout.txt $O/layout.txt; say "regenerated layout.txt equals the committed one: cmp rc=$?"
for f in s25_tests hash_domain r19b; do
  $C $f > $O/l13merge_$f.log 2>&1; say "hashline $f rc=$?"
  grep -E "^test result" $O/l13merge_$f.log >> $P
done
for m in ZK60Formal.SlotW16Build ZK60Formal.SlotW16BuildEval ZK60Formal.SlotW16BuildSlots ZK60Formal.SlotW16BuildLayout \
         ZK60Formal.SlotW16Compose; do
  $LAKE -d $R/formal build $m > $O/l13merge_prebuild.log 2>&1; say "lake build $m rc=$?"
done
$LAKE -d $R/formal build > $O/l13merge_lake.log 2>&1; say "lake build (full) rc=$?"
tail -2 $O/l13merge_lake.log >> $P
grep -ciE "warning|sorry" $O/l13merge_lake.log | sed 's/^/lines naming a warning or sorry in the build log: /' >> $P
for A in $O/axioms_l13.lean $O15/axioms_l15.lean $O10/axioms_l10.lean $O12/axioms_l12.lean $O9/axioms_l9.lean \
         $O11/axioms_l11.lean; do
  b=$(basename $A .lean)
  $LAKE -d $R/formal env lean $A > $O/l13merge_$b.log 2>&1; say "axiom audit $b rc=$?"
  grep -cE "sorryAx|ofReduceBool" $O/l13merge_$b.log | sed 's/^/sorryAx or ofReduceBool mentions: /' >> $P
  grep -oE "axioms: \[[^]]*\]" $O/l13merge_$b.log | sort | uniq -c >> $P
done
grep -n -E '\bsorry\b|\baxiom\b|native_decide|admit|maxRecDepth|maxHeartbeats|implemented_by|@\[extern|bv_decide|ofReduceBool' \
  $L/SlotW16Build.lean $L/SlotW16BuildEval.lean $L/SlotW16BuildSlots.lean $L/SlotW16BuildLayout.lean \
  $L/SlotW16Compose.lean $L/SlotW16BuildCheck.lean > $O/l13merge_scan.log; say "source scan hits (grep rc 1 = none): rc=$?"
$LAKE -d $R/formal env lean --run $L/SlotW16BuildCheck.lean $O/layout.txt $O11/corpus.txt > $O/l13merge_l13check.log 2>&1
say "SlotW16BuildCheck rc=$?"
tail -1 $O/l13merge_l13check.log >> $P
python3 -I $O/mutate_l13.py $O/layout.txt $O11/corpus.txt $S/lay_mut.txt $S/cor_mut.txt
$LAKE -d $R/formal env lean --run $L/SlotW16BuildCheck.lean $S/lay_mut.txt $S/cor_mut.txt > $O/l13merge_negative.log 2>&1
say "negative control (7 single changes must give exactly 7 failed)"
tail -1 $O/l13merge_negative.log >> $P
ulimit -s 65520
$LAKE -d $R/formal env lean --run $L/ExecBlockCheck.lean $O9/corpus.txt $F > $O/l13merge_l9check.log 2>&1
say "ExecBlockCheck regression rc=$?"
tail -1 $O/l13merge_l9check.log >> $P
$LAKE -d $R/formal env lean --run $L/L11Check.lean $O11/corpus.txt > $O/l13merge_l11check.log 2>&1; say "L11Check rc=$?"
tail -1 $O/l13merge_l11check.log >> $P
$LAKE -d $R/formal env lean --run $L/L6Check.lean $O6/corpus.txt > $O/l13merge_l6check.log 2>&1; say "L6Check rc=$?"
tail -1 $O/l13merge_l6check.log >> $P
$LAKE -d $R/formal env lean --run $L/L5Check.lean $O5/corpus.txt > $O/l13merge_l5check.log 2>&1; say "L5Check rc=$?"
tail -1 $O/l13merge_l5check.log >> $P
$LAKE -d $R/formal env lean --run $L/L1Check.lean $V/block_fixture_t32.tsv \
  $V/block_trace_low_h24_t32.tsv $V/block_trace_low_t32.tsv $R1/rust_fixture_trace.tsv $V/r13_requant_vectors.tsv \
  > $O/l13merge_l1check.log 2>&1; say "fixture L1 check rc=$?"
tail -1 $O/l13merge_l1check.log >> $P
say "all done"
