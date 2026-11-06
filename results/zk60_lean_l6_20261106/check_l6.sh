#!/bin/bash
# D63 step L6 Lean lane (2026-11-06): the full Lean build, the axiom audit, the source scan, the agreement check and the
# negative control, as ONE guarded job. Run through run_guarded.py (the zk60 resource guard, class cpu).
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a18b9cae3877467ba
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
OUT=$WT/results/zk60_lean_l6_20261106
FILES="$WT/formal/ZK60Formal/ExecMle.lean $WT/formal/ZK60Formal/ExecSumcheck.lean $WT/formal/ZK60Formal/ExecCfs.lean $WT/formal/ZK60Formal/L6Check.lean"
echo "== lake build (full) =="
"$LAKE" -d "$WT/formal" build > "$OUT/full.log" 2>&1
rc=$?
echo "lake build rc $rc"
tail -n 3 "$OUT/full.log"
echo "warnings: $(grep -c 'warning' "$OUT/full.log")"
echo "errors: $(grep -c 'error' "$OUT/full.log")"
echo "== axiom audit =="
python3 -I "$OUT/gen_axioms.py" "$WT/formal/ZK60Formal" "$OUT/axioms_l6.lean"
"$LAKE" -d "$WT/formal" env lean "$OUT/axioms_l6.lean" > "$OUT/axioms.log" 2>&1
arc=$?
echo "axioms rc $arc"
echo "declarations audited: $(grep -c 'depends on axioms\|does not depend on any axioms' "$OUT/axioms.log")"
echo "sorryAx: $(grep -c 'sorryAx' "$OUT/axioms.log")"
echo "other axioms: $(grep 'depends on axioms' "$OUT/axioms.log" | grep -v -E "\[(propext|Classical.choice|Quot.sound)(, (propext|Classical.choice|Quot.sound))*\]" | wc -l | tr -d ' ')"
echo "== source scan of the L6 files =="
grep -n -E '\bsorry\b|\baxiom\b|native_decide|admit|maxRecDepth|maxHeartbeats|implemented_by|@\[extern|bv_decide|ofReduceBool' $FILES || echo "none"
echo "== agreement check (L6Check.lean on corpus.txt) =="
"$LAKE" -d "$WT/formal" env lean --run "$WT/formal/ZK60Formal/L6Check.lean" "$OUT/corpus.txt" > "$OUT/l6check_full.log" 2>&1
crc=$?
tail -n 40 "$OUT/l6check_full.log"
echo "check rc $crc"
echo "== negative control (eight single changes; exactly 8 must fail) =="
python3 -I "$OUT/mutate_corpus.py" "$OUT/corpus.txt" "$OUT/corpus_mutated.tmp"
"$LAKE" -d "$WT/formal" env lean --run "$WT/formal/ZK60Formal/L6Check.lean" "$OUT/corpus_mutated.tmp" > "$OUT/negative_control.log" 2>&1
grep -E '^FAILED|^L6Check' "$OUT/negative_control.log" | cut -c1-160
rm -f "$OUT/corpus_mutated.tmp"
nrc=1
grep -q '^L6Check: .* checks, 8 failed$' "$OUT/negative_control.log" && nrc=0
echo "negative control rc $nrc"
[ $rc -eq 0 ] && [ $arc -eq 0 ] && [ $crc -eq 0 ] && [ $nrc -eq 0 ]
