#!/bin/bash
# Independent single-file elaboration of RunBlkPinsHd.lean (review copy = source + #print axioms appendix).
# No .olean is written (no -o). Writes nothing under formal/.
export LEAN_NUM_THREADS=2
REPO=/Users/victorrielly/IntelligenceRegulation
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
OUT=$REPO/results/zk60_claude_review_20261116/l66_review
start=$(date +%s)
"$LAKE" -d "$REPO/formal" env lean "$OUT/RunBlkPinsHd_review_copy.lean" < /dev/null > "$OUT/l66_elab.out" 2>&1
rc=$?
echo "elab rc $rc, $(( $(date +%s) - start )) s"
exit $rc
