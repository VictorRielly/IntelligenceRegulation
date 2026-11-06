#!/bin/bash
# D63 L1/L2 second Lean lane: the full Lean build, then the L1 check and the axiom audit (one guarded cpu job).
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-abd25deed597b23bd
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
R=$W/results/zk60_lean_l2b_20261106
R1=$W/results/zk60_lean_l1l2_20261106
V=$W/ops/zkp-mvp/gpu-metal/hashline/src/private_block/r13_vectors
echo "== full build"
$LAKE -d $W/formal build
rc=$?
echo "== full build rc=$rc"
if [ $rc -ne 0 ]; then exit $rc; fi
echo "== L1 check"
$LAKE -d $W/formal env lean --run $W/formal/ZK60Formal/L1Check.lean $V/block_fixture_t32.tsv \
  $V/block_trace_low_h24_t32.tsv $V/block_trace_low_t32.tsv $R1/rust_fixture_trace.tsv $V/r13_requant_vectors.tsv \
  > $R/l1check.log 2>&1
l1=$?
echo "== L1 check rc=$l1"
echo "== axioms"
$LAKE -d $W/formal env lean $R/axioms_l2b.lean > $R/axioms.log 2>&1
ax=$?
echo "== axioms rc=$ax"
if [ $l1 -ne 0 ] || [ $ax -ne 0 ]; then exit 1; fi
exit 0
