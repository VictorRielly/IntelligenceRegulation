#!/bin/bash
# D63 step L8 (Fiat-Shamir composition on the code's own transcript chain), merged into perf: the check on the MERGED
# tree in the main checkout. L8 adds no Rust; the zkp-core suite still runs (about 10 s) and regenerates both corpora
# into scratch, each compared byte for byte with its committed corpus.txt. Then the full Lean build of formal/, the L8
# and (as a regression) L7 axiom audits, the source scan, and as regressions L6Check, L5Check and the fixture L1 check.
# One guarded job, class cpu.
set -u
R=/Users/victorrielly/IntelligenceRegulation
O=$R/results/zk60_lean_l8_20261106
O7=$R/results/zk60_lean_l7_20261106
O6=$R/results/zk60_lean_l6_20261106
O5=$R/results/zk60_lean_l5_20261106
R1=$R/results/zk60_lean_l1l2_20261106
V=$R/ops/zkp-mvp/gpu-metal/hashline/src/private_block/r13_vectors
Z=$R/ops/zkp-mvp/gpu-metal/zkp-core/Cargo.toml
S=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
P=$O/l8merge.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
rm -f $S/l8merge_corpus5.txt $S/l8merge_corpus6.txt
env LEAN_L5_CORPUS=$S/l8merge_corpus5.txt LEAN_L6_CORPUS=$S/l8merge_corpus6.txt /opt/homebrew/bin/cargo test --release \
  --offline --locked -j 2 --manifest-path $Z > $O/l8merge_zkpcore.log 2>&1; say "zkp-core whole test suite rc=$?"
grep -E "^test result|^     Running" $O/l8merge_zkpcore.log | sed 's/(\/.*\/deps\//(deps\//' >> $P
cmp $S/l8merge_corpus6.txt $O6/corpus.txt; say "regenerated L6 corpus equals the committed L6 corpus.txt: cmp rc=$?"
cmp $S/l8merge_corpus5.txt $O5/corpus.txt; say "regenerated L5 corpus equals the committed L5 corpus.txt: cmp rc=$?"
$LAKE -d $R/formal build > $O/l8merge_lake.log 2>&1; rc=$?; say "lake build rc=$rc"
tail -2 $O/l8merge_lake.log >> $P
grep -ciE "warning|sorry" $O/l8merge_lake.log | sed 's/^/lines naming a warning or sorry in the build log: /' >> $P
for A in $O/axioms_l8.lean $O7/axioms_l7.lean; do
  b=$(basename $A .lean)
  $LAKE -d $R/formal env lean $A > $O/l8merge_$b.log 2>&1; say "axiom audit $b rc=$?"
  grep -cE "sorryAx|ofReduceBool" $O/l8merge_$b.log | sed 's/^/sorryAx or ofReduceBool mentions: /' >> $P
  grep -oE "axioms: \[[^]]*\]" $O/l8merge_$b.log | sort | uniq -c >> $P
  grep -cE "does not depend on any axioms" $O/l8merge_$b.log | sed 's/^/declarations with no axioms: /' >> $P
done
grep -n -E '\bsorry\b|\baxiom\b|native_decide|admit|maxRecDepth|maxHeartbeats|implemented_by|@\[extern|bv_decide|ofReduceBool' \
  $R/formal/ZK60Formal/ExecComposeFS.lean > $O/l8merge_scan.log; say "source scan hits (grep rc 1 = none): rc=$?"
$LAKE -d $R/formal env lean --run $R/formal/ZK60Formal/L6Check.lean $O6/corpus.txt > $O/l8merge_l6check.log 2>&1
say "L6Check regression rc=$?"
tail -1 $O/l8merge_l6check.log >> $P
$LAKE -d $R/formal env lean --run $R/formal/ZK60Formal/L5Check.lean $O5/corpus.txt > $O/l8merge_l5check.log 2>&1
say "L5Check regression rc=$?"
tail -1 $O/l8merge_l5check.log >> $P
$LAKE -d $R/formal env lean --run $R/formal/ZK60Formal/L1Check.lean $V/block_fixture_t32.tsv \
  $V/block_trace_low_h24_t32.tsv $V/block_trace_low_t32.tsv $R1/rust_fixture_trace.tsv $V/r13_requant_vectors.tsv \
  > $O/l8merge_l1check.log 2>&1; say "fixture L1 check rc=$?"
tail -1 $O/l8merge_l1check.log >> $P
say "all done"
