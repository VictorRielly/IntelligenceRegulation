#!/bin/bash
# D63 step L7 Lean lane (2026-11-06): the full Lean build, the axiom audit of every theorem of ExecSumcheckFS.lean, the
# source scan, and as regressions L6Check and L5Check on their committed corpora, as ONE guarded job. Run through
# run_guarded.py (the zk60 resource guard, class cpu). No Rust: L7 adds no export (the L5 / L6 corpora pin the encodings).
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a5a7d943600e67a25
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
OUT=$WT/results/zk60_lean_l7_20261106
O6=$WT/results/zk60_lean_l6_20261106
O5=$WT/results/zk60_lean_l5_20261106
FILES="$WT/formal/ZK60Formal/ExecSumcheckFS.lean"
echo "== lake build (full) =="
"$LAKE" -d "$WT/formal" build > "$OUT/full.log" 2>&1
rc=$?
echo "lake build rc $rc"
tail -n 3 "$OUT/full.log"
echo "warnings: $(grep -c 'warning' "$OUT/full.log")"
echo "errors: $(grep -c 'error' "$OUT/full.log")"
echo "sorry: $(grep -c 'sorry' "$OUT/full.log")"
echo "== axiom audit =="
python3 -I "$OUT/gen_axioms.py" "$WT/formal/ZK60Formal" "$OUT/axioms_l7.lean"
"$LAKE" -d "$WT/formal" env lean "$OUT/axioms_l7.lean" > "$OUT/axioms.log" 2>&1
arc=$?
echo "axioms rc $arc"
echo "declarations audited: $(grep -c 'depends on axioms\|does not depend on any axioms' "$OUT/axioms.log")"
echo "sorryAx: $(grep -c 'sorryAx' "$OUT/axioms.log")"
echo "ofReduceBool: $(grep -c 'ofReduceBool' "$OUT/axioms.log")"
echo "other axioms: $(grep 'depends on axioms' "$OUT/axioms.log" | grep -v -E "\[(propext|Classical.choice|Quot.sound)(, (propext|Classical.choice|Quot.sound))*\]" | wc -l | tr -d ' ')"
grep -oE "axioms: \[[^]]*\]" "$OUT/axioms.log" | sort | uniq -c
echo "== source scan of the L7 file =="
grep -n -E '\bsorry\b|\baxiom\b|native_decide|admit|maxRecDepth|maxHeartbeats|implemented_by|@\[extern|bv_decide|ofReduceBool' $FILES || echo "none"
echo "== the library root imports the L7 file =="
grep -n "ZK60Formal.ExecSumcheckFS" "$WT/formal/ZK60Formal.lean" || echo "MISSING"
echo "== regression: L6Check on the committed L6 corpus =="
"$LAKE" -d "$WT/formal" env lean --run "$WT/formal/ZK60Formal/L6Check.lean" "$O6/corpus.txt" > "$OUT/l6check_regression.log" 2>&1
c6=$?
tail -n 1 "$OUT/l6check_regression.log"
echo "L6Check rc $c6"
echo "== regression: L5Check on the committed L5 corpus =="
"$LAKE" -d "$WT/formal" env lean --run "$WT/formal/ZK60Formal/L5Check.lean" "$O5/corpus.txt" > "$OUT/l5check_regression.log" 2>&1
c5=$?
tail -n 1 "$OUT/l5check_regression.log"
echo "L5Check rc $c5"
g6=1
grep -q '^L6Check: 1206 checks, 0 failed$' "$OUT/l6check_regression.log" && g6=0
g5=1
grep -q '^L5Check: 5553 checks, 0 failed$' "$OUT/l5check_regression.log" && g5=0
echo "regression verdicts: L6 $g6, L5 $g5 (0 = the committed count with 0 failed)"
[ $rc -eq 0 ] && [ $arc -eq 0 ] && [ $c6 -eq 0 ] && [ $c5 -eq 0 ] && [ $g6 -eq 0 ] && [ $g5 -eq 0 ]
