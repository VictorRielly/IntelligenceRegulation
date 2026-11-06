#!/bin/bash
# D63 generic lemmas (Lean only; no Rust changed), merged into perf: the full Lean build of formal/ on the merged tree, the
# assembly's axiom audit, and the fixture L1 check as a regression. One guarded job, class cpu.
set -u
R=/Users/victorrielly/IntelligenceRegulation
O=$R/results/zk60_lean_gen_20261106
R1=$R/results/zk60_lean_l1l2_20261106
V=$R/ops/zkp-mvp/gpu-metal/hashline/src/private_block/r13_vectors
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
P=$O/genmerge.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$LAKE -d $R/formal build > $O/genmerge_lake.log 2>&1; rc=$?; say "lake build rc=$rc"
tail -2 $O/genmerge_lake.log >> $P
grep -ciE "warning|sorry" $O/genmerge_lake.log | sed 's/^/lines naming a warning or sorry in the build log: /' >> $P
$LAKE -d $R/formal env lean $O/axioms_gen.lean > $O/genmerge_axioms.log 2>&1; say "axiom audit rc=$?"
grep -cE "sorryAx" $O/genmerge_axioms.log | sed 's/^/sorryAx mentions: /' >> $P
grep -oE "axioms: \[[^]]*\]" $O/genmerge_axioms.log | sort | uniq -c >> $P
$LAKE -d $R/formal env lean --run $R/formal/ZK60Formal/L1Check.lean $V/block_fixture_t32.tsv \
  $V/block_trace_low_h24_t32.tsv $V/block_trace_low_t32.tsv $R1/rust_fixture_trace.tsv $V/r13_requant_vectors.tsv \
  > $O/genmerge_l1check.log 2>&1; say "fixture L1 check rc=$?"
tail -1 $O/genmerge_l1check.log >> $P
say "all done"
