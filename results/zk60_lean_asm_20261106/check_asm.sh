#!/bin/bash
# D63 assembly Lean lane (2026-11-06): the full Lean build, the axiom audit and the source scan, as ONE guarded job.
# Run through run_guarded.py (the zk60 resource guard, class cpu).
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a753c00c22277754e
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
OUT=$WT/results/zk60_lean_asm_20261106
echo "== lake build (full) =="
"$LAKE" -d "$WT/formal" build > "$OUT/full.log" 2>&1
rc=$?
echo "lake build rc $rc"
tail -n 3 "$OUT/full.log"
echo "warnings: $(grep -c 'warning' "$OUT/full.log")"
echo "errors: $(grep -c 'error' "$OUT/full.log")"
echo "== axiom audit =="
"$LAKE" -d "$WT/formal" env lean "$OUT/axioms_asm.lean" > "$OUT/axioms.log" 2>&1
arc=$?
echo "axioms rc $arc"
echo "theorems audited: $(grep -c 'depends on axioms\|does not depend on any axioms' "$OUT/axioms.log")"
echo "sorryAx: $(grep -c 'sorryAx' "$OUT/axioms.log")"
echo "== source scan of Assembly.lean =="
grep -n -E '\bsorry\b|\baxiom\b|native_decide|admit|maxRecDepth|maxHeartbeats|implemented_by' "$WT/formal/ZK60Formal/Assembly.lean" || echo "none"
[ $rc -eq 0 ] && [ $arc -eq 0 ]
