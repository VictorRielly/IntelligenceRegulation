#!/bin/bash
# D63 lane L22 Lean lane (2026-11-07): build the named modules (with their dependencies), then elaborate the named files
# with `lake env lean` (run through run_guarded.py, the zk60 resource guard, class cpu). A copy of
# results/zk60_lean_l16_20261107/stage.sh with this worktree's path. Modules are built ONE AT A TIME (as
# results/zk60_lean_l13_20261107/check_l13.sh does), so a fresh worktree's parallel build stays under the cap.
# usage: stage.sh "<modules to build>" <file.lean> [more files]
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a0faa117f66eac2c6
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
start=$(date +%s)
mods="$1"
shift
brc=0
for m in $mods; do
  echo "== lake build $m =="
  "$LAKE" -d "$WT/formal" build "$m" 2>&1 | grep -v '^✔\|^⣿\|Replayed\|Built' | head -n 300
  r=${PIPESTATUS[0]}
  echo "build rc $r for $m, $(( $(date +%s) - start )) s"
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
