#!/bin/bash
# D63 step L9 Lean lane (2026-11-07): build the named modules one after another with their full messages, stopping at
# the first that fails; with RUNCHECK=1 then run ExecBlockCheck.lean on the corpus and the frame. Run through
# run_guarded.py (the zk60 resource guard, class cpu).
# usage: stage2.sh <module> [more modules]
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-abdecaa028b7cbdaf
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
OUT=$WT/results/zk60_lean_l9_20261107
start=$(date +%s)
for m in "$@"; do
  echo "== lake build $m =="
  "$LAKE" -d "$WT/formal" build "$m" 2>&1 | grep -v '^✔\|^⣿\|Replayed\|^Build completed'
  r=${PIPESTATUS[0]}
  echo "rc $r for $m, $(( $(date +%s) - start )) s"
  if [ $r -ne 0 ]; then exit $r; fi
done
if [ "$RUNCHECK" = "1" ]; then
  echo "== ExecBlockCheck =="
  # the decoder's readers recurse once per word of a clear vector (16,664 at W16R2): a larger stack for the interpreter
  ulimit -s 65520
  "$LAKE" -d "$WT/formal" env lean --run "$WT/formal/ZK60Formal/ExecBlockCheck.lean" "$OUT/corpus.txt" "$OUT/fork_frame.bin"
  r=$?
  echo "check rc $r, $(( $(date +%s) - start )) s"
  exit $r
fi
