#!/bin/bash
# D63 step L9 (the W16R2 block verifier in executable Lean), merged into perf after L11: the check on the MERGED tree
# in the main checkout. It regenerates the L9 corpus and the uncommitted fork frame into scratch with the test-only
# hashline export, and compares the corpus byte for byte with the committed corpus.txt. Then it re-runs the L11 export
# (both lanes' test modules now sit beside each other) and the r19b census (TEST_ONLY_FILES is now 83). After that:
# the full Lean build; the L9, L11, L8 and L7 axiom audits; the source scan of the L9 files; ExecBlockCheck on the
# regenerated frame and its negative control; L11Check; and as regressions L6Check, L5Check and the fixture L1 check.
# One guarded job, class cpu.
set -u
R=/Users/victorrielly/IntelligenceRegulation
O=$R/results/zk60_lean_l9_20261107
O11=$R/results/zk60_lean_l11_20261107
O8=$R/results/zk60_lean_l8_20261106
O7=$R/results/zk60_lean_l7_20261106
O6=$R/results/zk60_lean_l6_20261106
O5=$R/results/zk60_lean_l5_20261106
R1=$R/results/zk60_lean_l1l2_20261106
V=$R/ops/zkp-mvp/gpu-metal/hashline/src/private_block/r13_vectors
L=$R/formal/ZK60Formal
M=$R/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
S=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/l9merge
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
C="/opt/homebrew/bin/cargo test --release --offline --locked -j 2 --manifest-path $M --lib"
P=$O/l9merge.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
rm -rf $S; mkdir -p $S
env L9_OUT=$S $C lean_l9_export_the_w16r2_rung_block -- --nocapture --test-threads 1 > $O/l9merge_export.log 2>&1
say "hashline lean_l9_export (test only) rc=$?"
grep -E "^test result" $O/l9merge_export.log >> $P
cmp $S/corpus.txt $O/corpus.txt; say "regenerated L9 corpus equals the committed corpus.txt: cmp rc=$?"
ls -l $S/fork_frame.bin | awk '{print "regenerated fork frame bytes: " $5}' >> $P
env LEAN_L11_CORPUS=$S/l11_corpus.txt $C lean_l11_export -- --nocapture > $O/l9merge_l11export.log 2>&1
say "hashline lean_l11_export (test only) rc=$?"
cmp $S/l11_corpus.txt $O11/corpus.txt; say "regenerated L11 corpus equals L11's committed corpus.txt: cmp rc=$?"
$C r19b > $O/l9merge_r19b.log 2>&1; say "hashline r19b census tests rc=$?"
grep -E "^test result" $O/l9merge_r19b.log >> $P
$LAKE -d $R/formal build > $O/l9merge_lake.log 2>&1; say "lake build rc=$?"
tail -2 $O/l9merge_lake.log >> $P
grep -ciE "warning|sorry" $O/l9merge_lake.log | sed 's/^/lines naming a warning or sorry in the build log: /' >> $P
for A in $O/axioms_l9.lean $O11/axioms_l11.lean $O8/axioms_l8.lean $O7/axioms_l7.lean; do
  b=$(basename $A .lean)
  $LAKE -d $R/formal env lean $A > $O/l9merge_$b.log 2>&1; say "axiom audit $b rc=$?"
  grep -cE "sorryAx|ofReduceBool" $O/l9merge_$b.log | sed 's/^/sorryAx or ofReduceBool mentions: /' >> $P
  grep -oE "axioms: \[[^]]*\]" $O/l9merge_$b.log | sort | uniq -c >> $P
  grep -cE "does not depend on any axioms" $O/l9merge_$b.log | sed 's/^/declarations with no axioms: /' >> $P
done
grep -n -E '\bsorry\b|\baxiom\b|native_decide|admit|maxRecDepth|maxHeartbeats|implemented_by|@\[extern|bv_decide|ofReduceBool' \
  $L/ExecBlockWire.lean $L/ExecBlockVerify.lean $L/ExecBlockFS.lean $L/ExecBlockCheck.lean > $O/l9merge_scan.log
say "source scan hits (grep rc 1 = none): rc=$?"
ulimit -s 65520
$LAKE -d $R/formal env lean --run $L/ExecBlockCheck.lean $O/corpus.txt $S/fork_frame.bin > $O/l9merge_l9check.log 2>&1
say "ExecBlockCheck on the committed corpus and the regenerated frame rc=$?"
tail -1 $O/l9merge_l9check.log >> $P
python3 -I $O/mutate_corpus.py $O/corpus.txt $S/corpus_mutated.txt
$LAKE -d $R/formal env lean --run $L/ExecBlockCheck.lean $S/corpus_mutated.txt $S/fork_frame.bin > $O/l9merge_negative.log 2>&1
say "negative control (6 single changes must give exactly 6 failures)"
tail -1 $O/l9merge_negative.log >> $P
$LAKE -d $R/formal env lean --run $L/L11Check.lean $O11/corpus.txt > $O/l9merge_l11check.log 2>&1; say "L11Check rc=$?"
tail -1 $O/l9merge_l11check.log >> $P
$LAKE -d $R/formal env lean --run $L/L6Check.lean $O6/corpus.txt > $O/l9merge_l6check.log 2>&1; say "L6Check rc=$?"
tail -1 $O/l9merge_l6check.log >> $P
$LAKE -d $R/formal env lean --run $L/L5Check.lean $O5/corpus.txt > $O/l9merge_l5check.log 2>&1; say "L5Check rc=$?"
tail -1 $O/l9merge_l5check.log >> $P
$LAKE -d $R/formal env lean --run $L/L1Check.lean $V/block_fixture_t32.tsv \
  $V/block_trace_low_h24_t32.tsv $V/block_trace_low_t32.tsv $R1/rust_fixture_trace.tsv $V/r13_requant_vectors.tsv \
  > $O/l9merge_l1check.log 2>&1; say "fixture L1 check rc=$?"
tail -1 $O/l9merge_l1check.log >> $P
say "all done"
