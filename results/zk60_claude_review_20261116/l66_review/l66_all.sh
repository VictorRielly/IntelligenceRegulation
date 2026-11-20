#!/bin/bash
# Reviewer's second guarded job: (1) freshly elaborated binder dump and use analysis of the top theorem (copy2),
# (2) the hCsIO literal-match test against the branch file RunStgShieldIOLink.lean. No .olean written.
export LEAN_NUM_THREADS=2
REPO=/Users/victorrielly/IntelligenceRegulation
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
OUT=$REPO/results/zk60_claude_review_20261116/l66_review
start=$(date +%s)
"$LAKE" -d "$REPO/formal" env lean "$OUT/RunBlkPinsHd_review_copy2.lean" < /dev/null > "$OUT/l66_meta.out" 2>&1
echo "meta rc $?, $(( $(date +%s) - start )) s"
"$LAKE" -d "$REPO/formal" env lean "$OUT/IOLinkTest.lean" < /dev/null > "$OUT/iolink_test.out" 2>&1
echo "iolink rc $?, $(( $(date +%s) - start )) s"
