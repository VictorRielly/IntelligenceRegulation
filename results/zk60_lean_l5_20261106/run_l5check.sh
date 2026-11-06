#!/bin/bash
# D63 step L5 Lean lane (2026-11-06): build the executable foundation's modules, then run the agreement checker on the
# corpus (run through run_guarded.py, the zk60 resource guard, class cpu).
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a27bb5b90225b127d
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
OUT=$WT/results/zk60_lean_l5_20261106
start=$(date +%s)
"$LAKE" -d "$WT/formal" build ZK60Formal.ExecMerkle ZK60Formal.L5Vectors 2>&1 | tail -n 3
"$LAKE" -d "$WT/formal" env lean --run "$WT/formal/ZK60Formal/L5Check.lean" "$OUT/corpus.txt"
rc=$?
echo "rc $rc, $(( $(date +%s) - start )) s"
exit $rc
