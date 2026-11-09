#!/bin/bash
# D63 lane L28 Lean lane (2026-11-07): build the named modules one at a time (with their dependencies), then the
# modules listed in plan.txt (if any), then elaborate the named files with `lake env lean` (run through
# run_guarded.py, the zk60 resource guard, class cpu). A copy of results/zk60_lean_l16_20261107/stage.sh with this
# worktree's path and the plan file.
# usage: stage.sh "<modules to build>" [file.lean ...]
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a4163c065a4c5517f
O=$WT/results/zk60_lean_l28_20261107
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
start=$(date +%s)
mods="$1 $(cat $O/plan.txt 2>/dev/null)"
shift
brc=0
for m in $mods; do
  echo "== lake build $m =="
  "$LAKE" -d "$WT/formal" build "$m" 2>&1 | grep -v '^✔\|^⣿\|Replayed\|Built' | head -n 400
  r=${PIPESTATUS[0]}
  echo "build rc $r for $m ($(( $(date +%s) - start )) s)"
  [ $r -ne 0 ] && brc=$r
done
rc=0
for f in "$@"; do
  echo "== lean $f =="
  "$LAKE" -d "$WT/formal" env lean "$f"
  r=$?
  echo "rc $r for $f"
  [ $r -ne 0 ] && rc=$r
done
echo "rc build $brc files $rc, $(( $(date +%s) - start )) s"
[ $brc -eq 0 ] && [ $rc -eq 0 ]
