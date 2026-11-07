#!/bin/bash
# D63 Lean lane L25 (2026-11-07): a fresh worktree's first build, the library root's modules one target at a time
# (in parallel the first build exceeds the cap; results/zk60_lean_l19_20261107/prebuild.sh). Run through
# run_guarded.py (the zk60 resource guard, class cpu).
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a3d358068f62b6713
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
OUT=$WT/results/zk60_lean_l25_20261107
start=$(date +%s)
fail=0
for m in $(grep '^import ' "$WT/formal/ZK60Formal.lean" | awk '{print $2}'); do
  "$LAKE" -d "$WT/formal" build "$m" > "$OUT/prebuild_last.log" 2>&1 || { echo "prebuild FAILED at $m"; grep -v '^✔\|^⣿\|Replayed\|Built' "$OUT/prebuild_last.log" | head -n 150; fail=1; }
done
echo "prebuild done, fail $fail, $(( $(date +%s) - start )) s"
[ $fail -eq 0 ]
