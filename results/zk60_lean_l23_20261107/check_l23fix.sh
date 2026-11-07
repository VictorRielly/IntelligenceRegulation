#!/bin/bash
# Finding L23-1, the fix: ExecBlockVerify.slotAcc now weights each hosted slot's mask in a host's Gamma functional
# with the HOSTED slot's own sum weights (its shape's n + e and degree), as the code does (argument.rs:1500,
# `sum_weights(&sh, *hs)`). Before, it used the host's. This is a correction of the Lean model to the code; no statement
# or target changes. The check on the merged tree (L9-L23):
# - the full Lean build, which shows whether any downstream proof depended on the old weights;
# - the axiom audits of every weekend lane (L9-L23), and the source scan of ExecBlockVerify.lean;
# - ExecBlockCheck on L9's corpus. Its slot / M / opening arithmetic is still the transcript-only stand-in (L9), so
#   it re-checks the transcript and the decoding;
# - the regressions L11Check, SlotW16BuildCheck, L6Check, L5Check and the fixture L1 check.
# One guarded job, class cpu.
set -u
R=/Users/victorrielly/IntelligenceRegulation
O=$R/results/zk60_lean_l23_20261107
L=$R/formal/ZK60Formal
V=$R/ops/zkp-mvp/gpu-metal/hashline/src/private_block/r13_vectors
R1=$R/results/zk60_lean_l1l2_20261106
F=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/l9merge/fork_frame.bin
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
P=$O/l23fix.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$LAKE -d $R/formal build > $O/l23fix_lake.log 2>&1; say "lake build rc=$?"
tail -3 $O/l23fix_lake.log >> $P
grep -E "^error|error:" $O/l23fix_lake.log | head -30 >> $P
grep -ciE "warning|sorry" $O/l23fix_lake.log | sed 's/^/lines naming a warning or sorry in the build log: /' >> $P
for n in 23 21 20 19 18 17 16 15 14 13 12 11 10 9; do
  A=$(ls $R/results/zk60_lean_l${n}_20261107/axioms_l${n}.lean 2>/dev/null) || continue
  $LAKE -d $R/formal env lean $A > $O/l23fix_axioms_l$n.log 2>&1; say "axiom audit l$n rc=$?"
  grep -cE "sorryAx|ofReduceBool" $O/l23fix_axioms_l$n.log | sed 's/^/sorryAx or ofReduceBool mentions: /' >> $P
done
grep -n -E '\bsorry\b|\baxiom\b|native_decide|admit|maxRecDepth|maxHeartbeats|implemented_by|@\[extern|bv_decide|ofReduceBool' \
  $L/ExecBlockVerify.lean > $O/l23fix_scan.log; say "source scan of ExecBlockVerify.lean (grep rc 1 = none): rc=$?"
ulimit -s 65520
$LAKE -d $R/formal env lean --run $L/ExecBlockCheck.lean $R/results/zk60_lean_l9_20261107/corpus.txt $F > $O/l23fix_l9check.log 2>&1
say "ExecBlockCheck rc=$?"; tail -1 $O/l23fix_l9check.log >> $P
$LAKE -d $R/formal env lean --run $L/L11Check.lean $R/results/zk60_lean_l11_20261107/corpus.txt > $O/l23fix_l11check.log 2>&1
say "L11Check rc=$?"; tail -1 $O/l23fix_l11check.log >> $P
$LAKE -d $R/formal env lean --run $L/SlotW16BuildCheck.lean $R/results/zk60_lean_l13_20261107/layout.txt \
  $R/results/zk60_lean_l11_20261107/corpus.txt > $O/l23fix_l13check.log 2>&1; say "SlotW16BuildCheck rc=$?"
tail -1 $O/l23fix_l13check.log >> $P
$LAKE -d $R/formal env lean --run $L/L6Check.lean $R/results/zk60_lean_l6_20261106/corpus.txt > $O/l23fix_l6check.log 2>&1
say "L6Check rc=$?"; tail -1 $O/l23fix_l6check.log >> $P
$LAKE -d $R/formal env lean --run $L/L5Check.lean $R/results/zk60_lean_l5_20261106/corpus.txt > $O/l23fix_l5check.log 2>&1
say "L5Check rc=$?"; tail -1 $O/l23fix_l5check.log >> $P
$LAKE -d $R/formal env lean --run $L/L1Check.lean $V/block_fixture_t32.tsv \
  $V/block_trace_low_h24_t32.tsv $V/block_trace_low_t32.tsv $R1/rust_fixture_trace.tsv $V/r13_requant_vectors.tsv \
  > $O/l23fix_l1check.log 2>&1; say "fixture L1 check rc=$?"
tail -1 $O/l23fix_l1check.log >> $P
say "all done"
