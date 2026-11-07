#!/bin/bash
# D63 lane L10 (2026-11-07): build the named modules, then elaborate each named file under bisect.py's RSS watchdog;
# after each file that elaborates cleanly, build its module (so the next file can import it). Run through run_guarded.py.
# usage: stage2.sh "<modules to build first>" <Module:file.lean> [more Module:file.lean]
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a9f0e162e79db6aa4
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
OUT=$WT/results/zk60_lean_l10_20261107
start=$(date +%s)
echo "== lake build $1 =="
"$LAKE" -d "$WT/formal" build $1 2>&1 | grep -v '^✔\|^⣿\|Replayed\|Built\|^trace' | grep -v 'warning' | head -n 100
shift
for mf in "$@"; do
  m=${mf%%:*}
  f=${mf#*:}
  python3 "$OUT/bisect.py" 9 600 "$f" | tee /private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/l10/stage2_last.txt
  if grep -q ': rc 0 ' /private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/l10/stage2_last.txt; then
    echo "== lake build $m =="
    "$LAKE" -d "$WT/formal" build "$m" 2>&1 | grep -v '^✔\|^⣿\|Replayed\|Built\|^trace' | grep -v 'warning' | head -n 60
  else
    echo "stop: $f did not elaborate"
    break
  fi
done
echo "total $(( $(date +%s) - start )) s"
