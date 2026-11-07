#!/bin/bash
# D63 step L11 Lean lane (2026-11-07): one iteration while writing the files: build the L11 modules (with their
# dependencies), elaborate the hand-off file, then run L11Check on the corpus. Run through run_guarded.py (class cpu).
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a7b7bd2255186ea2f
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
L=$WT/formal/ZK60Formal
OUT=$WT/results/zk60_lean_l11_20261107
start=$(date +%s)
echo "== lake build the L11 modules =="
"$LAKE" -d "$WT/formal" build ZK60Formal.SlotW16Ir ZK60Formal.SlotW16R2 ZK60Formal.SlotW16Sound ZK60Formal.LayoutW16 2>&1 \
  | grep -v '^✔\|^⣿\|Replayed\|Built' | head -n 150
echo "build rc ${PIPESTATUS[0]}"
echo "== lean LayoutW16Handoff.lean =="
"$LAKE" -d "$WT/formal" env lean "$L/LayoutW16Handoff.lean"
echo "rc $?"
echo "== L11Check =="
"$LAKE" -d "$WT/formal" env lean --run "$L/L11Check.lean" "$OUT/corpus.txt" 2>&1 | head -n 120
echo "rc ${PIPESTATUS[0]}, $(( $(date +%s) - start )) s"
