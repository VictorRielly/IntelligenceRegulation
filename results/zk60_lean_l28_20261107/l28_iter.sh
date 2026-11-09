#!/bin/bash
# D63 lane L28 (resumed 2026-11-09): build the named modules in order, each to its own log, and STOP at the first one
# that fails (stage.sh goes on, which repeats a failed dependency's errors under every later module). Run through
# run_guarded.py (the zk60 resource guard, class cpu).
# usage: l28_iter.sh <tag> <module> [module ...]      (module = a name under ZK60Formal, e.g. LinkW16Pcs)
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a4163c065a4c5517f
O=$WT/results/zk60_lean_l28_20261107
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
tag=$1
shift
start=$(date +%s)
for m in "$@"; do
  "$LAKE" -d "$WT/formal" build "ZK60Formal.$m" > "$O/l28_${tag}_$m.log" 2>&1
  r=$?
  echo "build rc $r for $m ($(( $(date +%s) - start )) s): $(grep -c '^error' "$O/l28_${tag}_$m.log") errors, $(grep -c '^warning' "$O/l28_${tag}_$m.log") warnings"
  if [ $r -ne 0 ]; then
    echo "STOPPED at $m"
    exit 1
  fi
done
echo "all green, $(( $(date +%s) - start )) s"
