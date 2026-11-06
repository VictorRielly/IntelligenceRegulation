#!/bin/bash
# D63 step L5 Lean lane (2026-11-06): the full Lean build, the axiom audit, the source scan and the agreement check, as
# ONE guarded job. Run through run_guarded.py (the zk60 resource guard, class cpu).
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a27bb5b90225b127d
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
OUT=$WT/results/zk60_lean_l5_20261106
FILES="$WT/formal/ZK60Formal/ExecField.lean $WT/formal/ZK60Formal/ExecBlake3.lean $WT/formal/ZK60Formal/ExecTranscript.lean $WT/formal/ZK60Formal/ExecMerkle.lean $WT/formal/ZK60Formal/L5Vectors.lean $WT/formal/ZK60Formal/L5Check.lean"
echo "== lake build (full) =="
"$LAKE" -d "$WT/formal" build > "$OUT/full.log" 2>&1
rc=$?
echo "lake build rc $rc"
tail -n 3 "$OUT/full.log"
echo "warnings: $(grep -c 'warning' "$OUT/full.log")"
echo "errors: $(grep -c 'error' "$OUT/full.log")"
echo "== axiom audit =="
"$LAKE" -d "$WT/formal" env lean "$OUT/axioms_l5.lean" > "$OUT/axioms.log" 2>&1
arc=$?
echo "axioms rc $arc"
echo "declarations audited: $(grep -c 'depends on axioms\|does not depend on any axioms' "$OUT/axioms.log")"
echo "sorryAx: $(grep -c 'sorryAx' "$OUT/axioms.log")"
echo "other axioms: $(grep 'depends on axioms' "$OUT/axioms.log" | grep -v -E "\[(propext|Classical.choice|Quot.sound)(, (propext|Classical.choice|Quot.sound))*\]" | wc -l | tr -d ' ')"
echo "== source scan of the L5 files =="
grep -n -E '\bsorry\b|\baxiom\b|native_decide|admit|maxRecDepth|maxHeartbeats|implemented_by|@\[extern|bv_decide|ofReduceBool' $FILES || echo "none"
echo "== agreement check (L5Check.lean on corpus.txt) =="
"$LAKE" -d "$WT/formal" env lean --run "$WT/formal/ZK60Formal/L5Check.lean" "$OUT/corpus.txt" > "$OUT/l5check_full.log" 2>&1
crc=$?
tail -n 30 "$OUT/l5check_full.log"
echo "check rc $crc"
echo "== negative control (six single changes; exactly 6 must fail) =="
python3 -I "$OUT/mutate_corpus.py" "$OUT/corpus.txt" "$OUT/corpus_mutated.tmp"
"$LAKE" -d "$WT/formal" env lean --run "$WT/formal/ZK60Formal/L5Check.lean" "$OUT/corpus_mutated.tmp" > "$OUT/negative_control.log" 2>&1
grep -E '^FAILED|^L5Check' "$OUT/negative_control.log" | cut -c1-160
rm -f "$OUT/corpus_mutated.tmp"
nrc=1
grep -q '^L5Check: .* checks, 6 failed$' "$OUT/negative_control.log" && nrc=0
echo "negative control rc $nrc"
[ $rc -eq 0 ] && [ $arc -eq 0 ] && [ $crc -eq 0 ] && [ $nrc -eq 0 ]
