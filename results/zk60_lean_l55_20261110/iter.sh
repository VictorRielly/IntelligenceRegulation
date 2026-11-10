#!/bin/bash
# D63 lane L55 (2026-11-10): one iteration as ONE guarded job (run_guarded.py, class cpu). A copy of the fixed template
# results/zk60_lean_l26_20261107/iter.sh (finding L49-FZC-1: every command in the plan loop reads /dev/null) with this
# worktree's path, LEAN_NUM_THREADS=4 and L52's `run` step. It reads its plan file (default OUT/plan.txt, or the first
# argument) at run time, one step per line:
#   build <Module ...>   lake build of the named modules (with their dependencies)
#   lean <file.lean>     lake env lean of one file (a new file, or a probe)
#   run <file.lean> <args...>   lake env lean --run of a checker
#   check <script>       run a check script, only when every earlier step succeeded
# so that a queued job runs the plan as it stands when the guard admits it.
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a33fed333d77ee386
OUT=$WT/results/zk60_lean_l55_20261110
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
export LEAN_NUM_THREADS=4
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
      # < /dev/null: otherwise lake inherits the loop's stdin and can swallow the rest of the plan (finding L49-FZC-1)
      "$LAKE" -d "$WT/formal" build $arg < /dev/null 2>&1 | grep -v '^✔\|^⣿\|Replayed\|Built' | head -n 800
      r=${PIPESTATUS[0]}
      echo "build rc $r ($(( $(date +%s) - start )) s)"
      [ $r -ne 0 ] && rc=$r
      ;;
    lean)
      echo "== lean $arg =="
      "$LAKE" -d "$WT/formal" env lean "$arg" < /dev/null 2>&1 | head -n 800
      r=${PIPESTATUS[0]}
      echo "rc $r for $arg ($(( $(date +%s) - start )) s)"
      [ $r -ne 0 ] && rc=$r
      ;;
    run)
      echo "== lean --run $arg =="
      "$LAKE" -d "$WT/formal" env lean --run $arg < /dev/null 2>&1 | tail -n 200
      r=${PIPESTATUS[0]}
      echo "run rc $r ($(( $(date +%s) - start )) s)"
      [ $r -ne 0 ] && rc=$r
      ;;
    check)
      if [ $rc -eq 0 ]; then
        echo "== check $arg =="
        /bin/bash "$arg" < /dev/null > "$OUT/check.log" 2>&1
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
