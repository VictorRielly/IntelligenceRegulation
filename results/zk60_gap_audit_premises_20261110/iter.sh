#!/bin/bash
# Gap audit (premise register, 2026-11-10): one iteration as ONE guarded job (run_guarded.py, class cpu).
# A copy of results/zk60_lean_l34_20261109/iter.sh with this worktree's path. Plan file, one step per line:
#   build <Module ...>   lake build of the named modules
#   lean <file.lean>     lake env lean of one scratch file (never imported by the root)
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-ac5014c1840bb9c09
OUT=$WT/results/zk60_gap_audit_premises_20261110
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
PLAN=${1:-$OUT/plan.txt}
start=$(date +%s)
rc=0
echo "== plan $PLAN =="
cat "$PLAN"
while read -r kind arg; do
  [ -z "$kind" ] && continue
  case "$kind" in
    build)
      echo "== lake build $arg =="
      "$LAKE" -d "$WT/formal" build $arg 2>&1 | grep -v '^✔\|^⣿\|Replayed\|Built' | head -n 400
      r=${PIPESTATUS[0]}
      echo "build rc $r ($(( $(date +%s) - start )) s)"
      [ $r -ne 0 ] && rc=$r
      ;;
    lean)
      echo "== lean $arg =="
      "$LAKE" -d "$WT/formal" env lean "$arg" 2>&1 | head -n 3000
      r=${PIPESTATUS[0]}
      echo "rc $r for $arg ($(( $(date +%s) - start )) s)"
      [ $r -ne 0 ] && rc=$r
      ;;
  esac
done < "$PLAN"
echo "rc $rc, $(( $(date +%s) - start )) s"
exit $rc
