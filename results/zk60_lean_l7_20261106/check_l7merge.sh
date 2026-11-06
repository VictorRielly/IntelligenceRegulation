#!/bin/bash
# D63 step L7 (Fiat-Shamir soundness of the executable sumcheck verifier), merged into perf: the check on the MERGED
# tree in the main checkout. L7 adds no Rust; the zkp-core suite still runs (about 10 s) and regenerates both corpora
# into scratch, each compared byte for byte with its committed corpus.txt. Then the full Lean build of formal/, the L7
# axiom audit, the source scan, and as regressions L6Check, L5Check and the fixture L1 check. One guarded job, class cpu.
set -u
R=/Users/victorrielly/IntelligenceRegulation
O=$R/results/zk60_lean_l7_20261106
O6=$R/results/zk60_lean_l6_20261106
O5=$R/results/zk60_lean_l5_20261106
R1=$R/results/zk60_lean_l1l2_20261106
V=$R/ops/zkp-mvp/gpu-metal/hashline/src/private_block/r13_vectors
Z=$R/ops/zkp-mvp/gpu-metal/zkp-core/Cargo.toml
S=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
P=$O/l7merge.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
rm -f $S/l7merge_corpus5.txt $S/l7merge_corpus6.txt
env LEAN_L5_CORPUS=$S/l7merge_corpus5.txt LEAN_L6_CORPUS=$S/l7merge_corpus6.txt /opt/homebrew/bin/cargo test --release \
  --offline --locked -j 2 --manifest-path $Z > $O/l7merge_zkpcore.log 2>&1; say "zkp-core whole test suite rc=$?"
grep -E "^test result|^     Running" $O/l7merge_zkpcore.log | sed 's/(\/.*\/deps\//(deps\//' >> $P
cmp $S/l7merge_corpus6.txt $O6/corpus.txt; say "regenerated L6 corpus equals the committed L6 corpus.txt: cmp rc=$?"
cmp $S/l7merge_corpus5.txt $O5/corpus.txt; say "regenerated L5 corpus equals the committed L5 corpus.txt: cmp rc=$?"
$LAKE -d $R/formal build > $O/l7merge_lake.log 2>&1; rc=$?; say "lake build rc=$rc"
tail -2 $O/l7merge_lake.log >> $P
grep -ciE "warning|sorry" $O/l7merge_lake.log | sed 's/^/lines naming a warning or sorry in the build log: /' >> $P
$LAKE -d $R/formal env lean $O/axioms_l7.lean > $O/l7merge_axioms.log 2>&1; say "axiom audit rc=$?"
grep -cE "sorryAx|ofReduceBool" $O/l7merge_axioms.log | sed 's/^/sorryAx or ofReduceBool mentions: /' >> $P
grep -oE "axioms: \[[^]]*\]" $O/l7merge_axioms.log | sort | uniq -c >> $P
grep -cE "does not depend on any axioms" $O/l7merge_axioms.log | sed 's/^/declarations with no axioms: /' >> $P
grep -n -E '\bsorry\b|\baxiom\b|native_decide|admit|maxRecDepth|maxHeartbeats|implemented_by|@\[extern|bv_decide|ofReduceBool' \
  $R/formal/ZK60Formal/ExecSumcheckFS.lean > $O/l7merge_scan.log; say "source scan hits (grep rc 1 = none): rc=$?"
$LAKE -d $R/formal env lean --run $R/formal/ZK60Formal/L6Check.lean $O6/corpus.txt > $O/l7merge_l6check.log 2>&1
say "L6Check regression rc=$?"
tail -1 $O/l7merge_l6check.log >> $P
$LAKE -d $R/formal env lean --run $R/formal/ZK60Formal/L5Check.lean $O5/corpus.txt > $O/l7merge_l5check.log 2>&1
say "L5Check regression rc=$?"
tail -1 $O/l7merge_l5check.log >> $P
$LAKE -d $R/formal env lean --run $R/formal/ZK60Formal/L1Check.lean $V/block_fixture_t32.tsv \
  $V/block_trace_low_h24_t32.tsv $V/block_trace_low_t32.tsv $R1/rust_fixture_trace.tsv $V/r13_requant_vectors.tsv \
  > $O/l7merge_l1check.log 2>&1; say "fixture L1 check rc=$?"
tail -1 $O/l7merge_l1check.log >> $P
say "all done"
