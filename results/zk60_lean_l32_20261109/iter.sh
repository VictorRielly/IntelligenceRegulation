#!/bin/bash
# D63 lane L32 (2026-11-09): one iteration as ONE guarded job (run_guarded.py, class cpu). A copy of
# results/zk60_lean_l26_20261107/iter.sh with this worktree's path. It reads its plan file (default OUT/plan.txt, or the
# first argument) at RUN time, one step per line:
#   build <Module>       lake build of the named module (with its dependencies)
#   lean <file.lean>     lake env lean of one file (a probe, the axiom audit)
#   check <script>       run a check script, only when every earlier step succeeded
# so that a queued job runs the plan as it stands when the guard admits it.
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a56025bec34e68f4b
OUT=$WT/results/zk60_lean_l32_20261109
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
      "$LAKE" -d "$WT/formal" build $arg 2>&1 | grep -v '^✔\|^⣿\|Replayed\|Built\|^trace: ' | sed "s|$WT/formal/||g" | cut -c1-3000 | head -n 400
      r=${PIPESTATUS[0]}
      echo "build rc $r for $arg ($(( $(date +%s) - start )) s)"
      [ $r -ne 0 ] && rc=$r
      ;;
    lean)
      echo "== lean $arg =="
      "$LAKE" -d "$WT/formal" env lean "$arg" 2>&1 | cut -c1-3000 | head -n 400
      r=${PIPESTATUS[0]}
      echo "rc $r for $arg ($(( $(date +%s) - start )) s)"
      [ $r -ne 0 ] && rc=$r
      ;;
    check)
      if [ $rc -eq 0 ]; then
        echo "== check $arg =="
        /bin/bash "$arg" > "$OUT/check.log" 2>&1
        r=$?
        echo "check rc $r ($(( $(date +%s) - start )) s); its log is check.log"
        tail -n 60 "$OUT/check.log"
        [ $r -ne 0 ] && rc=$r
      else
        echo "== check $arg skipped: an earlier step failed =="
      fi
      ;;
  esac
done < "$PLAN"
echo "rc $rc, $(( $(date +%s) - start )) s"
exit $rc
