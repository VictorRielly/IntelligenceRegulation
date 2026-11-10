#!/bin/bash
# D63 lane L40 (2026-11-10): run the lane's checker RunShapeCheck (the approved block, through its computable twin,
# on the committed R13 trace fixture), as one step of a guarded iteration (iter.sh `check`).
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a87ee5a3c81d92fe4
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
OUT=$WT/results/zk60_lean_l40_20261110
R1=$WT/results/zk60_lean_l1l2_20261106
V=$WT/ops/zkp-mvp/gpu-metal/hashline/src/private_block/r13_vectors
ulimit -s 65520
start=$(date +%s)
"$LAKE" -d "$WT/formal" env lean --run "$WT/formal/ZK60Formal/RunShapeCheck.lean" "$V/block_fixture_t32.tsv" \
  "$V/block_trace_low_h24_t32.tsv" "$V/block_trace_low_t32.tsv" "$R1/rust_fixture_trace.tsv" "$V/silu_-4_-13.bin" \
  "$V/silu_-1_-11.bin" "$WT/results/zk60_lean_l2d_20261106/rust_token_out.tsv" > "$OUT/runshapecheck.log" 2>&1
rc=$?
cat "$OUT/runshapecheck.log"
echo "RunShapeCheck rc $rc, $(( $(date +%s) - start )) s"
exit $rc
