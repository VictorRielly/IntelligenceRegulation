#!/bin/bash
# D63 step L15 (stages OUT-C and OUT whole, their Fiat-Shamir form, a stage corpus), merged into perf after L9, L10,
# L11, L12 and A24: the check on the MERGED tree in the main checkout. This includes the census, because TEST_ONLY_FILES
# merged to 85 (A24's classify_serve_tests + L15's export).
# The test-only export regenerates the L15 corpus into scratch (cmp with the committed one); hashline s25, hash_domain,
# r19b and token_io::classify (with the R13 loader fixtures named; A24's serve tests and L15's export sit there); the
# full Lean build; the L15, L10, L12, L9, L11, L8 and L7 axiom audits; the source scan of the L15 files; StageCheckOutC
# and its negative control; and as regressions ExecBlockCheck, L11Check, L6Check, L5Check and the fixture L1 check.
# One guarded job, class cpu.
set -u
R=/Users/victorrielly/IntelligenceRegulation
O=$R/results/zk60_lean_l15_20261107
O10=$R/results/zk60_lean_l10_20261107
O12=$R/results/zk60_lean_l12_20261107
O9=$R/results/zk60_lean_l9_20261107
O11=$R/results/zk60_lean_l11_20261107
O8=$R/results/zk60_lean_l8_20261106
O7=$R/results/zk60_lean_l7_20261106
O6=$R/results/zk60_lean_l6_20261106
O5=$R/results/zk60_lean_l5_20261106
R1=$R/results/zk60_lean_l1l2_20261106
V=$R/ops/zkp-mvp/gpu-metal/hashline/src/private_block/r13_vectors
L=$R/formal/ZK60Formal
M=$R/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
S=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/l15merge
F=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/l9merge/fork_frame.bin
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
C="/opt/homebrew/bin/cargo test --release --offline --locked -j 2 --manifest-path $M --lib"
P=$O/l15merge.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
rm -rf $S; mkdir -p $S
env LEAN_L15_CORPUS=$S/corpus.txt $C lean_l15_export -- --nocapture > $O/l15merge_export.log 2>&1
say "hashline lean_l15_export (test only) rc=$?"
grep -E "^test result" $O/l15merge_export.log >> $P
cmp $S/corpus.txt $O/corpus.txt; say "regenerated L15 corpus equals the committed corpus.txt: cmp rc=$?"
for f in s25_tests hash_domain r19b; do
  $C $f > $O/l15merge_$f.log 2>&1; say "hashline $f rc=$?"
  grep -E "^test result" $O/l15merge_$f.log >> $P
done
env HL_R13_LOADER_FIXTURES=$R/results/zk60_1b_native_20261017/r13/loader-fixtures $C token_io::classify \
  > $O/l15merge_classify.log 2>&1; say "hashline token_io::classify (R13 loader fixtures named) rc=$?"
grep -E "^test result" $O/l15merge_classify.log >> $P
$LAKE -d $R/formal build > $O/l15merge_lake.log 2>&1; say "lake build rc=$?"
tail -2 $O/l15merge_lake.log >> $P
grep -ciE "warning|sorry" $O/l15merge_lake.log | sed 's/^/lines naming a warning or sorry in the build log: /' >> $P
for A in $O/axioms_l15.lean $O10/axioms_l10.lean $O12/axioms_l12.lean $O9/axioms_l9.lean $O11/axioms_l11.lean \
         $O8/axioms_l8.lean $O7/axioms_l7.lean; do
  b=$(basename $A .lean)
  $LAKE -d $R/formal env lean $A > $O/l15merge_$b.log 2>&1; say "axiom audit $b rc=$?"
  grep -cE "sorryAx|ofReduceBool" $O/l15merge_$b.log | sed 's/^/sorryAx or ofReduceBool mentions: /' >> $P
  grep -oE "axioms: \[[^]]*\]" $O/l15merge_$b.log | sort | uniq -c >> $P
  grep -cE "does not depend on any axioms" $O/l15merge_$b.log | sed 's/^/declarations with no axioms: /' >> $P
done
grep -n -E '\bsorry\b|\baxiom\b|native_decide|admit|maxRecDepth|maxHeartbeats|implemented_by|@\[extern|bv_decide|ofReduceBool' \
  $L/StageOutCWhole.lean $L/StageOutWhole.lean $L/StageFS.lean $L/StageCheckDefs.lean $L/StageCheckValid.lean \
  $L/StageCheckOutC.lean > $O/l15merge_scan.log; say "source scan hits (grep rc 1 = none): rc=$?"
$LAKE -d $R/formal env lean --run $L/StageCheckOutC.lean $O/corpus.txt > $O/l15merge_stagecheck.log 2>&1
say "StageCheckOutC rc=$?"
tail -1 $O/l15merge_stagecheck.log >> $P
python3 -I $O/mutate_corpus.py $O/corpus.txt $S/mutated.txt
$LAKE -d $R/formal env lean --run $L/StageCheckOutC.lean $S/mutated.txt > $O/l15merge_negative.log 2>&1
say "negative control (8 mutations must give exactly 8 failed)"
tail -1 $O/l15merge_negative.log >> $P
ulimit -s 65520
$LAKE -d $R/formal env lean --run $L/ExecBlockCheck.lean $O9/corpus.txt $F > $O/l15merge_l9check.log 2>&1
say "ExecBlockCheck regression rc=$?"
tail -1 $O/l15merge_l9check.log >> $P
$LAKE -d $R/formal env lean --run $L/L11Check.lean $O11/corpus.txt > $O/l15merge_l11check.log 2>&1; say "L11Check rc=$?"
tail -1 $O/l15merge_l11check.log >> $P
$LAKE -d $R/formal env lean --run $L/L6Check.lean $O6/corpus.txt > $O/l15merge_l6check.log 2>&1; say "L6Check rc=$?"
tail -1 $O/l15merge_l6check.log >> $P
$LAKE -d $R/formal env lean --run $L/L5Check.lean $O5/corpus.txt > $O/l15merge_l5check.log 2>&1; say "L5Check rc=$?"
tail -1 $O/l15merge_l5check.log >> $P
$LAKE -d $R/formal env lean --run $L/L1Check.lean $V/block_fixture_t32.tsv \
  $V/block_trace_low_h24_t32.tsv $V/block_trace_low_t32.tsv $R1/rust_fixture_trace.tsv $V/r13_requant_vectors.tsv \
  > $O/l15merge_l1check.log 2>&1; say "fixture L1 check rc=$?"
tail -1 $O/l15merge_l1check.log >> $P
say "all done"
