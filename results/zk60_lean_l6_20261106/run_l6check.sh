#!/bin/bash
# D63 step L6 Lean lane (2026-11-06): build the executable sumcheck modules, then run the agreement checker on the corpus
# (or on the corpus given as $1) (run through run_guarded.py, the zk60 resource guard, class cpu).
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a18b9cae3877467ba
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
OUT=$WT/results/zk60_lean_l6_20261106
CORPUS=${1:-$OUT/corpus.txt}
start=$(date +%s)
"$LAKE" -d "$WT/formal" build ZK60Formal.ExecSumcheck ZK60Formal.ExecCfs 2>&1 | grep -v '^✔\|^⣿\|Replayed\|Built' | tail -n 40
"$LAKE" -d "$WT/formal" env lean --run "$WT/formal/ZK60Formal/L6Check.lean" "$CORPUS"
rc=$?
echo "rc $rc, $(( $(date +%s) - start )) s"
exit $rc
