#!/bin/bash
# Independent single-file elaborations of RunShieldInstP.lean and RunStgShieldLu.lean (review copies = source + #print axioms appendix).
# No .olean is written (no -o). Writes nothing under formal/ (the binder dump writes only into this directory).
export LEAN_NUM_THREADS=2
REPO=/Users/victorrielly/IntelligenceRegulation
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
OUT=$REPO/results/zk60_claude_review_20261116/l67_review
start=$(date +%s)
"$LAKE" -d "$REPO/formal" env lean "$OUT/RunShieldInstP_review_copy.lean" < /dev/null > "$OUT/inst_elab.out" 2>&1
echo "inst rc $?, $(( $(date +%s) - start )) s"
"$LAKE" -d "$REPO/formal" env lean "$OUT/RunStgShieldLu_review_copy.lean" < /dev/null > "$OUT/lu_elab.out" 2>&1
echo "lu rc $?, $(( $(date +%s) - start )) s"
