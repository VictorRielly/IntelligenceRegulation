#!/bin/bash
# D63 step L13 Lean lane (2026-11-07): build the named modules, then run SlotW16BuildCheck on the layout export and the
# L11 corpus (run through run_guarded.py, class cpu).
# usage: iterate.sh "<modules to build>"
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a30bf89c063c9ac1c
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
start=$(date +%s)
echo "== lake build $1 =="
"$LAKE" -d "$WT/formal" build $1 2>&1 | grep -v '^✔\|^⣿\|Replayed\|Built' | head -n 900
brc=${PIPESTATUS[0]}
echo "build rc $brc"
echo "== SlotW16BuildCheck =="
"$LAKE" -d "$WT/formal" env lean --run "$WT/formal/ZK60Formal/SlotW16BuildCheck.lean" \
  "$WT/results/zk60_lean_l13_20261107/layout.txt" "$WT/results/zk60_lean_l11_20261107/corpus.txt" 2>&1 | head -n 120
crc=${PIPESTATUS[0]}
echo "rc build $brc check $crc, $(( $(date +%s) - start )) s"
[ $brc -eq 0 ] && [ $crc -eq 0 ]
