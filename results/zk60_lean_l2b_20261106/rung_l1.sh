#!/bin/bash
# D63 L1/L2 third Lean lane (2026-11-06): the L1 check with the T = 128 rung as its sixth argument (one guarded cpu
# job). The rung TSV (about 4 MB) is NOT committed: extract it from the export's log with
#   extract_rung.py <rust_rung.log> <out.tsv> t128-h24 t128-low
# and pass <out.tsv> as $1. The fixture arguments are those of full.sh.
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a7c39ce7cc88eb1b0
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
R=$W/results/zk60_lean_l2b_20261106
R1=$W/results/zk60_lean_l1l2_20261106
V=$W/ops/zkp-mvp/gpu-metal/hashline/src/private_block/r13_vectors
RUNG=$1
shasum -a 256 "$RUNG"
$LAKE -d $W/formal env lean --run $W/formal/ZK60Formal/L1Check.lean $V/block_fixture_t32.tsv \
  $V/block_trace_low_h24_t32.tsv $V/block_trace_low_t32.tsv $R1/rust_fixture_trace.tsv $V/r13_requant_vectors.tsv \
  "$RUNG" > $R/l1check_rung.log 2>&1
rc=$?
echo "== L1 check with the rung rc=$rc"
tail -1 $R/l1check_rung.log
exit $rc
