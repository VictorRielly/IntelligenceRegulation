#!/bin/bash
# D63 step L5 (the verifier's foundation), merged into perf: the check on the MERGED tree in the main checkout. Rust is
# test-only (zkp-core tests/lean_l5_export.rs). So: the whole zkp-core test suite, which also regenerates the corpus
# into scratch, compared byte for byte with the committed corpus.txt; the full Lean build of formal/; the L5 axiom
# audit; L5Check on the committed corpus; the fixture L1 check as a regression. One guarded job, class cpu.
set -u
R=/Users/victorrielly/IntelligenceRegulation
O=$R/results/zk60_lean_l5_20261106
R1=$R/results/zk60_lean_l1l2_20261106
V=$R/ops/zkp-mvp/gpu-metal/hashline/src/private_block/r13_vectors
Z=$R/ops/zkp-mvp/gpu-metal/zkp-core/Cargo.toml
S=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
P=$O/l5merge.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
rm -f $S/l5merge_corpus.txt
env LEAN_L5_CORPUS=$S/l5merge_corpus.txt /opt/homebrew/bin/cargo test --release --offline --locked -j 2 --manifest-path $Z \
  > $O/l5merge_zkpcore.log 2>&1; say "zkp-core whole test suite rc=$?"
grep -E "^test result|^     Running" $O/l5merge_zkpcore.log | sed 's/(\/.*\/deps\//(deps\//' >> $P
grep -E "^LEAN-L5" $O/l5merge_zkpcore.log | sed "s#$S#<scratch>#" >> $P
cmp $S/l5merge_corpus.txt $O/corpus.txt; say "regenerated corpus equals the committed corpus.txt: cmp rc=$?"
shasum -a 256 $O/corpus.txt | cut -c1-16 >> $P
$LAKE -d $R/formal build > $O/l5merge_lake.log 2>&1; rc=$?; say "lake build rc=$rc"
tail -2 $O/l5merge_lake.log >> $P
grep -ciE "warning|sorry" $O/l5merge_lake.log | sed 's/^/lines naming a warning or sorry in the build log: /' >> $P
$LAKE -d $R/formal env lean $O/axioms_l5.lean > $O/l5merge_axioms.log 2>&1; say "axiom audit rc=$?"
grep -cE "sorryAx" $O/l5merge_axioms.log | sed 's/^/sorryAx mentions: /' >> $P
grep -oE "axioms: \[[^]]*\]" $O/l5merge_axioms.log | sort | uniq -c >> $P
grep -cE "does not depend on any axioms" $O/l5merge_axioms.log | sed 's/^/declarations with no axioms: /' >> $P
$LAKE -d $R/formal env lean --run $R/formal/ZK60Formal/L5Check.lean $O/corpus.txt > $O/l5merge_l5check.log 2>&1
say "L5Check on the committed corpus rc=$?"
tail -1 $O/l5merge_l5check.log >> $P
$LAKE -d $R/formal env lean --run $R/formal/ZK60Formal/L1Check.lean $V/block_fixture_t32.tsv \
  $V/block_trace_low_h24_t32.tsv $V/block_trace_low_t32.tsv $R1/rust_fixture_trace.tsv $V/r13_requant_vectors.tsv \
  > $O/l5merge_l1check.log 2>&1; say "fixture L1 check rc=$?"
tail -1 $O/l5merge_l1check.log >> $P
say "all done"
