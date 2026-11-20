#!/bin/bash
# Independent single-file elaboration of RunShieldBlkInst.lean (review copy = source + #print axioms + meta appendix). No .olean written (no -o).
export LEAN_NUM_THREADS=2
REPO=/Users/victorrielly/IntelligenceRegulation
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
OUT=$REPO/results/zk60_claude_review_20261116/l68a_review
start=$(date +%s)
"$LAKE" -d "$REPO/formal" env lean "$OUT/RunShieldBlkInst_review_copy.lean" < /dev/null > "$OUT/blk_elab.out" 2>&1
echo "blk rc $?, $(( $(date +%s) - start )) s"
