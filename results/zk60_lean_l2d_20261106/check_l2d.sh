#!/bin/bash
# D63 L1/L2, fourth Lean lane (2026-11-06): the whole library build, the axiom audit, the stage-OUT L1 check and the
# block L1 checks (fixture and T = 128 rung), in one guarded job. Writes one log per step next to this script.
W=${W:-/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-aba956b0357d722a2}
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
R=$W/results/zk60_lean_l2d_20261106
V=$W/ops/zkp-mvp/gpu-metal/hashline/src/private_block/r13_vectors
cd "$W" || exit 9
"$LAKE" -d formal build > "$R/full.log" 2>&1; echo "full build rc $?" >> "$R/full.log"
"$LAKE" -d formal env lean "$R/axioms_l2d.lean" > "$R/axioms.log" 2>&1; echo "axioms rc $?" >> "$R/axioms.log"
"$LAKE" -d formal env lean --run formal/ZK60Formal/L1CheckOut.lean "$R/rust_token_out.tsv" \
  results/zk60_lean_l1l2_20261106/rust_fixture_trace.tsv > "$R/l1check_out.log" 2>&1
echo "l1check_out rc $?" >> "$R/l1check_out.log"
"$LAKE" -d formal env lean --run formal/ZK60Formal/L1Check.lean "$V/block_fixture_t32.tsv" \
  "$V/block_trace_low_h24_t32.tsv" "$V/block_trace_low_t32.tsv" results/zk60_lean_l1l2_20261106/rust_fixture_trace.tsv \
  "$V/r13_requant_vectors.tsv" > "$R/l1check_fixture.log" 2>&1
echo "l1check_fixture rc $?" >> "$R/l1check_fixture.log"
