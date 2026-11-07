#!/bin/bash
# D63 lane L10 (2026-11-07): build the named modules, then elaborate each named file under bisect.py's RSS watchdog;
# after each file that elaborates cleanly, build its module (so the next file can import it). Run through run_guarded.py.
# usage: stage2.sh "<modules to build first>" <Module:file.lean> [more Module:file.lean]
# A plan file (scratchpad/l10/stage2_plan.txt: line 1 the modules, then one Module:file per line), when present at the
# job's START, replaces the arguments (a job queued behind the heavy lock then runs the newest plan); it is renamed
# .used. A file that does not elaborate is reported and its module not built; the later files are still tried.
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a9f0e162e79db6aa4
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
OUT=$WT/results/zk60_lean_l10_20261107
SCR=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/l10
PLAN=$SCR/stage2_plan.txt
start=$(date +%s)
if [ -f "$PLAN" ]; then
  echo "== plan $PLAN =="
  cat "$PLAN"
  mods=$(head -n 1 "$PLAN")
  items=$(tail -n +2 "$PLAN")
  mv "$PLAN" "$PLAN.used"
else
  mods=$1
  shift
  items="$*"
fi
echo "== lake build $mods =="
"$LAKE" -d "$WT/formal" build $mods 2>&1 | grep -v '^✔\|^⣿\|Replayed\|Built\|^trace' | grep -v 'warning' | head -n 100
for mf in $items; do
  m=${mf%%:*}
  f=${mf#*:}
  python3 "$OUT/bisect.py" 9 900 "$f" | tee "$SCR/stage2_last.txt"
  if grep -q ': rc 0 ' "$SCR/stage2_last.txt"; then
    echo "== lake build $m =="
    "$LAKE" -d "$WT/formal" build "$m" 2>&1 | grep -v '^✔\|^⣿\|Replayed\|Built\|^trace' | grep -v 'warning' | head -n 60
  else
    echo "not built: $f did not elaborate"
  fi
done
echo "total $(( $(date +%s) - start )) s"
