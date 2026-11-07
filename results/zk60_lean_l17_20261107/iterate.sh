#!/bin/bash
# D63 Lean lane L17 (2026-11-07): one iteration while the R13 files are written: build the named library modules (with
# their dependencies, one `lake build` per module so that few run at once), then elaborate the named checker files
# with `lake env lean` (no run). Run through run_guarded.py (the zk60 resource guard, class cpu).
# usage: iterate.sh "<modules>" [checker.lean ...]
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a1625b90fca168135
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
start=$(date +%s)
mods="$1"
shift
brc=0
for m in $mods; do
  echo "== lake build $m =="
  "$LAKE" -d "$WT/formal" build "$m" 2>&1 | grep -v '^✔\|^⣿\|Replayed\|^Built\|^info: ' | head -n 120
  r=${PIPESTATUS[0]}
  echo "build rc $r for $m ($(( $(date +%s) - start )) s)"
  [ $r -ne 0 ] && brc=$r
done
rc=0
for f in "$@"; do
  echo "== lean $f =="
  "$LAKE" -d "$WT/formal" env lean "$f" 2>&1 | head -n 120
  r=${PIPESTATUS[0]}
  echo "rc $r for $f ($(( $(date +%s) - start )) s)"
  [ $r -ne 0 ] && rc=$r
done
echo "rc build $brc files $rc, $(( $(date +%s) - start )) s"
[ $brc -eq 0 ] && [ $rc -eq 0 ]
