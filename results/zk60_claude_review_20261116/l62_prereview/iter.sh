#!/bin/bash
# Claude's read-only L62 pre-review (2026-11-16): one iteration as ONE guarded job (run_guarded.py, class cpu,
# label lean-l62-review). A copy of the L63 lane's iter.sh (worktree agent-a8b5788916259e1b2,
# results/zk60_lean_l63_20261116/iter.sh); OUT is this review's directory, WT the L63 worktree (whose formal/.lake has
# RunBlkWireTop built). Output cap raised from 400 to 3000 lines so the full error list is kept.
# It reads its plan file (the first argument) at run time, one step per line:
#   build <Module ...>   lake build of the named modules (with their dependencies)
#   lean <file.lean>     lake env lean of one file (a new file, or a probe)
export LEAN_NUM_THREADS=4
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a8b5788916259e1b2
OUT=/Users/victorrielly/IntelligenceRegulation/results/zk60_claude_review_20261116/l62_prereview
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
      # < /dev/null: otherwise lake inherits the loop's stdin and can swallow the rest of the plan (finding L49-FZC-1)
      "$LAKE" -d "$WT/formal" build $arg < /dev/null 2>&1 | grep -v '^✔\|^⣿\|Replayed\|Built' | head -n 3000
      r=${PIPESTATUS[0]}
      echo "build rc $r ($(( $(date +%s) - start )) s)"
      [ $r -ne 0 ] && rc=$r
      ;;
    lean)
      echo "== lean $arg =="
      "$LAKE" -d "$WT/formal" env lean "$arg" < /dev/null 2>&1 | head -n 3000
      r=${PIPESTATUS[0]}
      echo "rc $r for $arg ($(( $(date +%s) - start )) s)"
      [ $r -ne 0 ] && rc=$r
      ;;
  esac
done < "$PLAN"
echo "rc $rc, $(( $(date +%s) - start )) s"
exit $rc
