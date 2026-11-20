#!/bin/bash
# Single-file elaboration of the edited RunShieldBlkInst.lean (copy = source + #print axioms appendix). No .olean written.
export LEAN_NUM_THREADS=2
REPO=/Users/victorrielly/IntelligenceRegulation
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
OUT=$REPO/results/zk60_claude_review_20261116/l68a_recheck
start=$(date +%s)
"$LAKE" -d "$REPO/formal" env lean "$OUT/RunShieldBlkInst_recheck_copy_norfl.lean" < /dev/null > "$OUT/recheck_norfl_elab.out" 2>&1
rc=$?
echo "recheck rc $rc, $(( $(date +%s) - start )) s"
exit $rc
