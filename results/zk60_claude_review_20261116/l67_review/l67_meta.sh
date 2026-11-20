#!/bin/bash
export LEAN_NUM_THREADS=2
REPO=/Users/victorrielly/IntelligenceRegulation
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
OUT=$REPO/results/zk60_claude_review_20261116/l67_review
start=$(date +%s)
"$LAKE" -d "$REPO/formal" env lean "$OUT/L67Meta.lean" < /dev/null > "$OUT/meta.out" 2>&1
echo "meta rc $?, $(( $(date +%s) - start )) s"
