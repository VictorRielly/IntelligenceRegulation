#!/bin/bash
# D63 generic-lemma Lean lane (2026-11-06): build CompleteSub's module, then check ZKHybrid.lean, as ONE guarded job.
# Run through run_guarded.py (the zk60 resource guard, class cpu).
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-ac7a96c145c37fc1d
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
echo "== lake build ZK60Formal.CompleteSub =="
"$LAKE" -d "$WT/formal" build ZK60Formal.CompleteSub 2>&1 | tail -n 20
echo "== lean ZKHybrid.lean =="
"$LAKE" -d "$WT/formal" env lean "$WT/formal/ZK60Formal/ZKHybrid.lean"
