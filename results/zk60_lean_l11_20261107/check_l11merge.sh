#!/bin/bash
# D63 step L11 (the W16R2 slot arithmetization and the layout map), merged into perf: the check on the MERGED tree in
# the main checkout. It regenerates the L11 corpus with the test-only hashline export into scratch and compares it
# byte for byte with the committed corpus.txt. If they differ, it says so, and L11Check runs on BOTH. Then the full
# Lean build, the L11, L8 and L7 axiom audits, the source scan of the five L11 files, L11Check, its negative control,
# and as regressions L6Check, L5Check and the fixture L1 check. One guarded job, class cpu.
set -u
R=/Users/victorrielly/IntelligenceRegulation
O=$R/results/zk60_lean_l11_20261107
O8=$R/results/zk60_lean_l8_20261106
O7=$R/results/zk60_lean_l7_20261106
O6=$R/results/zk60_lean_l6_20261106
O5=$R/results/zk60_lean_l5_20261106
R1=$R/results/zk60_lean_l1l2_20261106
V=$R/ops/zkp-mvp/gpu-metal/hashline/src/private_block/r13_vectors
L=$R/formal/ZK60Formal
S=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
P=$O/l11merge.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
rm -f $S/l11merge_corpus.txt
env LEAN_L11_CORPUS=$S/l11merge_corpus.txt /opt/homebrew/bin/cargo test --release --offline --locked -j 2 \
  --manifest-path $R/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml --lib lean_l11_export -- --nocapture \
  > $O/l11merge_export.log 2>&1; say "hashline lean_l11_export (test only) rc=$?"
grep -E "^test result" $O/l11merge_export.log >> $P
cmp $S/l11merge_corpus.txt $O/corpus.txt; same=$?; say "regenerated L11 corpus equals the committed corpus.txt: cmp rc=$same"
$LAKE -d $R/formal build > $O/l11merge_lake.log 2>&1; say "lake build rc=$?"
tail -2 $O/l11merge_lake.log >> $P
grep -ciE "warning|sorry" $O/l11merge_lake.log | sed 's/^/lines naming a warning or sorry in the build log: /' >> $P
for A in $O/axioms_l11.lean $O8/axioms_l8.lean $O7/axioms_l7.lean; do
  b=$(basename $A .lean)
  $LAKE -d $R/formal env lean $A > $O/l11merge_$b.log 2>&1; say "axiom audit $b rc=$?"
  grep -cE "sorryAx|ofReduceBool" $O/l11merge_$b.log | sed 's/^/sorryAx or ofReduceBool mentions: /' >> $P
  grep -oE "axioms: \[[^]]*\]" $O/l11merge_$b.log | sort | uniq -c >> $P
  grep -cE "does not depend on any axioms" $O/l11merge_$b.log | sed 's/^/declarations with no axioms: /' >> $P
done
grep -n -E '\bsorry\b|\baxiom\b|native_decide|admit|maxRecDepth|maxHeartbeats|implemented_by|@\[extern|bv_decide|ofReduceBool' \
  $L/SlotW16Ir.lean $L/SlotW16R2.lean $L/SlotW16Sound.lean $L/LayoutW16.lean $L/LayoutW16Handoff.lean $L/L11Check.lean \
  > $O/l11merge_scan.log; say "source scan hits (grep rc 1 = none): rc=$?"
$LAKE -d $R/formal env lean --run $L/L11Check.lean $O/corpus.txt > $O/l11merge_l11check.log 2>&1
say "L11Check on the committed corpus rc=$?"
tail -1 $O/l11merge_l11check.log >> $P
if [ $same -ne 0 ] && [ -f $S/l11merge_corpus.txt ]; then
  $LAKE -d $R/formal env lean --run $L/L11Check.lean $S/l11merge_corpus.txt > $O/l11merge_l11check_regen.log 2>&1
  say "L11Check on the regenerated corpus rc=$?"
  tail -1 $O/l11merge_l11check_regen.log >> $P
fi
python3 -I $O/mutate_corpus.py $O/corpus.txt $S/l11merge_mutated.txt
$LAKE -d $R/formal env lean --run $L/L11Check.lean $S/l11merge_mutated.txt > $O/l11merge_negative.log 2>&1
say "negative control (7 single changes must give exactly 7 failures)"
tail -1 $O/l11merge_negative.log >> $P
$LAKE -d $R/formal env lean --run $L/L6Check.lean $O6/corpus.txt > $O/l11merge_l6check.log 2>&1; say "L6Check rc=$?"
tail -1 $O/l11merge_l6check.log >> $P
$LAKE -d $R/formal env lean --run $L/L5Check.lean $O5/corpus.txt > $O/l11merge_l5check.log 2>&1; say "L5Check rc=$?"
tail -1 $O/l11merge_l5check.log >> $P
$LAKE -d $R/formal env lean --run $L/L1Check.lean $V/block_fixture_t32.tsv \
  $V/block_trace_low_h24_t32.tsv $V/block_trace_low_t32.tsv $R1/rust_fixture_trace.tsv $V/r13_requant_vectors.tsv \
  > $O/l11merge_l1check.log 2>&1; say "fixture L1 check rc=$?"
tail -1 $O/l11merge_l1check.log >> $P
say "all done"
