#!/bin/bash
# D63 lane L32 Lean lane (2026-11-09): build the named modules (with their dependencies), then elaborate the named files
# with `lake env lean` (run through run_guarded.py, the zk60 resource guard, class cpu). A copy of
# results/zk60_lean_l29_20261107/stage.sh with this worktree's path. Each module is built on its own, so that one
# module's errors do not hide the next one's.
# usage: stage.sh "<modules to build>" <file.lean> [more files]
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a56025bec34e68f4b
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
start=$(date +%s)
mods="$1"
shift
brc=0
for m in $mods; do
  echo "== lake build $m =="
  "$LAKE" -d "$WT/formal" build $m 2>&1 | grep -v '^✔\|^⣿\|Replayed\|Built\|^trace: ' | sed "s|$WT/formal/||g" | cut -c1-3000 | head -n 500
  r=${PIPESTATUS[0]}
  echo "build rc $r for $m ($(( $(date +%s) - start )) s)"
  [ $r -ne 0 ] && brc=$r
done
rc=0
for f in "$@"; do
  echo "== lean $f =="
  "$LAKE" -d "$WT/formal" env lean "$f" 2>&1 | head -n 300
  r=${PIPESTATUS[0]}
  echo "rc $r for $f"
  [ $r -ne 0 ] && rc=$r
done
echo "rc build $brc files $rc, $(( $(date +%s) - start )) s"
[ $brc -eq 0 ] && [ $rc -eq 0 ]
