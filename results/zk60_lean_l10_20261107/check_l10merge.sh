#!/bin/bash
# D63 step L10 (the W16R2 openings, M's test, M under Fiat-Shamir, the L8-5 transfer, Binding), merged into perf after
# L9, L11, L12 and A24: the check on the MERGED tree in the main checkout. It regenerates the L10 corpus (191.9 MB, kept
# outside the repository) with the test-only export into scratch and compares its sha256 with corpus.sha256. Then the
# hashline census tests (s25, hash_domain, r19b: w16r2_tests.rs now declares the L9, L11 and L10 exports); the full
# Lean build; the L10, L12, L9, L11, L8 and L7 axiom audits; the source scan of the L10 files; the L10 checker on the
# reduced corpus (mksmall.py) and its negative control (negctl.py: exactly 8 failed); and as regressions ExecBlockCheck,
# L11Check, L6Check, L5Check and the fixture L1 check. One guarded job, class cpu.
set -u
R=/Users/victorrielly/IntelligenceRegulation
O=$R/results/zk60_lean_l10_20261107
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
S=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/l10merge
F=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/l9merge/fork_frame.bin
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
C="/opt/homebrew/bin/cargo test --release --offline --locked -j 2 --manifest-path $M --lib"
P=$O/l10merge.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
rm -rf $S; mkdir -p $S
env LEAN_L10_CORPUS=$S/corpus_w16r2.txt $C lean_l10_export -- --nocapture > $O/l10merge_export.log 2>&1
say "hashline lean_l10_export (test only) rc=$?"
grep -E "^test result" $O/l10merge_export.log >> $P
want=$(head -1 $O/corpus.sha256 | cut -d' ' -f1); got=$(shasum -a 256 $S/corpus_w16r2.txt | cut -d' ' -f1)
[ "$want" = "$got" ]; say "regenerated L10 corpus sha256 equals corpus.sha256 ($got): rc=$?"
for f in s25_tests hash_domain r19b; do
  $C $f > $O/l10merge_$f.log 2>&1; say "hashline $f rc=$?"
  grep -E "^test result" $O/l10merge_$f.log >> $P
done
$LAKE -d $R/formal build > $O/l10merge_lake.log 2>&1; say "lake build rc=$?"
tail -2 $O/l10merge_lake.log >> $P
grep -ciE "warning|sorry" $O/l10merge_lake.log | sed 's/^/lines naming a warning or sorry in the build log: /' >> $P
for A in $O/axioms_l10.lean $O12/axioms_l12.lean $O9/axioms_l9.lean $O11/axioms_l11.lean $O8/axioms_l8.lean $O7/axioms_l7.lean; do
  b=$(basename $A .lean)
  $LAKE -d $R/formal env lean $A > $O/l10merge_$b.log 2>&1; say "axiom audit $b rc=$?"
  grep -cE "sorryAx|ofReduceBool" $O/l10merge_$b.log | sed 's/^/sorryAx or ofReduceBool mentions: /' >> $P
  grep -oE "axioms: \[[^]]*\]" $O/l10merge_$b.log | sort | uniq -c >> $P
  grep -cE "does not depend on any axioms" $O/l10merge_$b.log | sed 's/^/declarations with no axioms: /' >> $P
done
grep -n -E '\bsorry\b|\baxiom\b|native_decide|admit|maxRecDepth|maxHeartbeats|implemented_by|@\[extern|bv_decide|ofReduceBool' \
  $L/ExecOpeningCode.lean $L/BindingW16.lean $L/ExecOpening.lean $L/ExecOpeningM.lean $L/ExecOpeningFS.lean \
  $L/ExecOpeningBlock.lean $L/ExecOpeningCheck.lean > $O/l10merge_scan.log
say "source scan hits (grep rc 1 = none): rc=$?"
python3 -I $O/mksmall.py $S/corpus_w16r2.txt $S/corpus_small.txt
$LAKE -d $R/formal env lean --run $L/ExecOpeningCheck.lean $S/corpus_small.txt > $O/l10merge_l10check_small.log 2>&1
say "L10 checker on the reduced corpus rc=$?"
tail -1 $O/l10merge_l10check_small.log >> $P
python3 -I $O/negctl.py $S/corpus_small.txt $S/corpus_neg.txt
$LAKE -d $R/formal env lean --run $L/ExecOpeningCheck.lean $S/corpus_neg.txt > $O/l10merge_l10check_neg.log 2>&1
say "negative control (6 single changes must give exactly 8 failed checks)"
tail -1 $O/l10merge_l10check_neg.log >> $P
ulimit -s 65520
$LAKE -d $R/formal env lean --run $L/ExecBlockCheck.lean $O9/corpus.txt $F > $O/l10merge_l9check.log 2>&1
say "ExecBlockCheck regression rc=$?"
tail -1 $O/l10merge_l9check.log >> $P
$LAKE -d $R/formal env lean --run $L/L11Check.lean $O11/corpus.txt > $O/l10merge_l11check.log 2>&1; say "L11Check rc=$?"
tail -1 $O/l10merge_l11check.log >> $P
$LAKE -d $R/formal env lean --run $L/L6Check.lean $O6/corpus.txt > $O/l10merge_l6check.log 2>&1; say "L6Check rc=$?"
tail -1 $O/l10merge_l6check.log >> $P
$LAKE -d $R/formal env lean --run $L/L5Check.lean $O5/corpus.txt > $O/l10merge_l5check.log 2>&1; say "L5Check rc=$?"
tail -1 $O/l10merge_l5check.log >> $P
$LAKE -d $R/formal env lean --run $L/L1Check.lean $V/block_fixture_t32.tsv \
  $V/block_trace_low_h24_t32.tsv $V/block_trace_low_t32.tsv $R1/rust_fixture_trace.tsv $V/r13_requant_vectors.tsv \
  > $O/l10merge_l1check.log 2>&1; say "fixture L1 check rc=$?"
tail -1 $O/l10merge_l1check.log >> $P
rm -f $S/corpus_w16r2.txt
say "all done (the regenerated 191.9 MB corpus removed from scratch)"
