#!/bin/bash
# D63 step L18 (the classify run's Protocol instance, its FS schedule, Complete, and ProductionReady), merged into perf
# after L9-L17 and L19-L21: the check on the MERGED tree in the main checkout.
# - The test-only export makes a FRESH corpus: the classifier fixture's run draws OS entropy, as L15's does, so it is
#   not byte-stable. ProtocolClassifyCheck runs on the committed corpus and on the fresh one, plus the negative control.
# - hashline: the census tests s25, hash_domain and r19b, and token_io::classify (classify_capture_tests.rs gained the
#   L18 module line; the R13 loader fixtures are named).
# - The full Lean build; the L18 and L21 axiom audits; and the source scan of the seven L18 files. Each file's header
#   sentence "no `sorry`, axiom or `native_decide`" is the only expected text match and is excluded.
# - Regressions: ExecBlockCheck, L11Check, L6Check, L5Check and the fixture L1 check.
# One guarded job, class cpu.
set -u
R=/Users/victorrielly/IntelligenceRegulation
O=$R/results/zk60_lean_l18_20261107
O21=$R/results/zk60_lean_l21_20261107
O9=$R/results/zk60_lean_l9_20261107
O11=$R/results/zk60_lean_l11_20261107
O6=$R/results/zk60_lean_l6_20261106
O5=$R/results/zk60_lean_l5_20261106
R1=$R/results/zk60_lean_l1l2_20261106
V=$R/ops/zkp-mvp/gpu-metal/hashline/src/private_block/r13_vectors
L=$R/formal/ZK60Formal
M=$R/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
S=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/l18merge
F=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/l9merge/fork_frame.bin
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
C="/opt/homebrew/bin/cargo test --release --offline --locked -j 2 --manifest-path $M --lib"
P=$O/l18merge.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
rm -rf $S; mkdir -p $S
env LEAN_L18_CORPUS=$S/corpus.txt $C lean_l18_export -- --nocapture > $O/l18merge_export.log 2>&1
say "hashline lean_l18_export (test only, fresh entropy) rc=$?"
grep -E "^test result" $O/l18merge_export.log >> $P
for f in s25_tests hash_domain r19b; do
  $C $f > $O/l18merge_$f.log 2>&1; say "hashline $f rc=$?"
  grep -E "^test result" $O/l18merge_$f.log >> $P
done
env HL_R13_LOADER_FIXTURES=$R/results/zk60_1b_native_20261017/r13/loader-fixtures $C token_io::classify \
  > $O/l18merge_classify.log 2>&1; say "hashline token_io::classify rc=$?"
grep -E "^test result" $O/l18merge_classify.log >> $P
$LAKE -d $R/formal build > $O/l18merge_lake.log 2>&1; say "lake build rc=$?"
tail -2 $O/l18merge_lake.log >> $P
grep -ciE "warning|sorry" $O/l18merge_lake.log | sed 's/^/lines naming a warning or sorry in the build log: /' >> $P
for A in $O/axioms_l18.lean $O21/axioms_l21.lean; do
  b=$(basename $A .lean)
  $LAKE -d $R/formal env lean $A > $O/l18merge_$b.log 2>&1; say "axiom audit $b rc=$?"
  grep -cE "sorryAx|ofReduceBool" $O/l18merge_$b.log | sed 's/^/sorryAx or ofReduceBool mentions: /' >> $P
  grep -oE "axioms: \[[^]]*\]" $O/l18merge_$b.log | sort | uniq -c >> $P
done
grep -n -E '\bsorry\b|\baxiom\b|native_decide|admit|maxRecDepth|maxHeartbeats|implemented_by|@\[extern|bv_decide|ofReduceBool' \
  $L/ProtocolClassify.lean $L/ProtocolClassifyFS.lean $L/ProtocolClassifyComplete.lean $L/AssembleClassify.lean \
  $L/ProtocolClassifyR13.lean $L/ProtocolClassifyCount.lean $L/ProtocolClassifyCheck.lean \
  | grep -v 'no `sorry`, axiom or' | grep -v ':`native_decide`\.$' > $O/l18merge_scan.log
say "source scan hits other than the header sentences (grep rc 1 = none): rc=$?"
$LAKE -d $R/formal env lean --run $L/ProtocolClassifyCheck.lean $O/corpus.txt > $O/l18merge_check.log 2>&1
say "ProtocolClassifyCheck on the committed corpus rc=$?"; tail -1 $O/l18merge_check.log >> $P
$LAKE -d $R/formal env lean --run $L/ProtocolClassifyCheck.lean $S/corpus.txt > $O/l18merge_check_fresh.log 2>&1
say "ProtocolClassifyCheck on the fresh corpus rc=$?"; tail -1 $O/l18merge_check_fresh.log >> $P
python3 -I $O/mutate_corpus.py $O/corpus.txt $S/mutated.txt
$LAKE -d $R/formal env lean --run $L/ProtocolClassifyCheck.lean $S/mutated.txt > $O/l18merge_negative.log 2>&1
say "negative control (5 mutations, 6 expected failures)"; tail -1 $O/l18merge_negative.log >> $P
ulimit -s 65520
$LAKE -d $R/formal env lean --run $L/ExecBlockCheck.lean $O9/corpus.txt $F > $O/l18merge_l9check.log 2>&1
say "ExecBlockCheck regression rc=$?"; tail -1 $O/l18merge_l9check.log >> $P
$LAKE -d $R/formal env lean --run $L/L11Check.lean $O11/corpus.txt > $O/l18merge_l11check.log 2>&1; say "L11Check rc=$?"
tail -1 $O/l18merge_l11check.log >> $P
$LAKE -d $R/formal env lean --run $L/L6Check.lean $O6/corpus.txt > $O/l18merge_l6check.log 2>&1; say "L6Check rc=$?"
tail -1 $O/l18merge_l6check.log >> $P
$LAKE -d $R/formal env lean --run $L/L5Check.lean $O5/corpus.txt > $O/l18merge_l5check.log 2>&1; say "L5Check rc=$?"
tail -1 $O/l18merge_l5check.log >> $P
$LAKE -d $R/formal env lean --run $L/L1Check.lean $V/block_fixture_t32.tsv \
  $V/block_trace_low_h24_t32.tsv $V/block_trace_low_t32.tsv $R1/rust_fixture_trace.tsv $V/r13_requant_vectors.tsv \
  > $O/l18merge_l1check.log 2>&1; say "fixture L1 check rc=$?"
tail -1 $O/l18merge_l1check.log >> $P
say "all done"
