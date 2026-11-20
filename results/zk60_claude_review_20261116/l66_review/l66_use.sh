#!/bin/bash
export LEAN_NUM_THREADS=2
REPO=/Users/victorrielly/IntelligenceRegulation
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
OUT=$REPO/results/zk60_claude_review_20261116/l66_review
"$LAKE" -d "$REPO/formal" env lean "$OUT/UseAnalysis.lean" < /dev/null > "$OUT/use_analysis.out" 2>&1
echo "use rc $?"
