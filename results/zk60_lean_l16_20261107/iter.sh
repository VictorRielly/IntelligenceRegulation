#!/bin/bash
# D63 lane L16 (2026-11-07): one iteration as ONE guarded job (run_guarded.py, class cpu). It reads its plan file
# (default OUT/plan.txt, or the first argument) at run time, one step per line:
#   build <Module ...>   lake build of the named modules (with their dependencies)
#   lean <file.lean>     lake env lean of one file (a new file, or a probe in the scratchpad)
# so that a queued job runs the plan as it stands when the guard admits it.
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a6dd8ecd1d3edee58
OUT=$WT/results/zk60_lean_l16_20261107
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
      "$LAKE" -d "$WT/formal" env lean "$arg" 2>&1 | head -n 400
      r=${PIPESTATUS[0]}
      echo "rc $r for $arg ($(( $(date +%s) - start )) s)"
      [ $r -ne 0 ] && rc=$r
      ;;
  esac
done < "$PLAN"
echo "rc $rc, $(( $(date +%s) - start )) s"
exit $rc
