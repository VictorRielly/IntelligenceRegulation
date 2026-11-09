#!/bin/bash
# D63 lane L26 Lean lane (2026-11-07): build the named modules (with their dependencies), then elaborate the named files
# with `lake env lean` (run through run_guarded.py, the zk60 resource guard, class cpu). A copy of
# results/zk60_lean_l16_20261107/stage.sh with this worktree's path.
# usage: stage.sh "<modules to build>" <file.lean> [more files]
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a51f9d1a2272ead49
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
start=$(date +%s)
mods="$1"
shift
brc=0
if [ -n "$mods" ]; then
  echo "== lake build $mods =="
  "$LAKE" -d "$WT/formal" build $mods 2>&1 | grep -v '^✔\|^⣿\|Replayed\|Built' | head -n 200
  brc=${PIPESTATUS[0]}
  echo "build rc $brc"
fi
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
