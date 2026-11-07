#!/bin/bash
# D63 step L14 Lean lane (2026-11-07, zero knowledge for one W16R2 block receipt): the full Lean build, the axiom audit
# of every theorem of the five L14 files, the source scan, the root imports, and the regressions L6Check, L5Check and
# L11Check on their committed corpora (the arguments of results/zk60_lean_l11_20261107/check_l11merge.sh), as ONE
# guarded job. Run through run_guarded.py (the zk60 resource guard, class cpu).
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a40ca7ccfcd16fc47
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
OUT=$WT/results/zk60_lean_l14_20261107
O6=$WT/results/zk60_lean_l6_20261106
O5=$WT/results/zk60_lean_l5_20261106
O11=$WT/results/zk60_lean_l11_20261107
L=$WT/formal/ZK60Formal
FILES="$L/ZKW16Prog.lean $L/ZKW16Step.lean $L/ZKW16View.lean $L/ZKW16Block.lean $L/ZKW16Hyb.lean"
echo "== lake build (full) =="
"$LAKE" -d "$WT/formal" build > "$OUT/full.log" 2>&1
rc=$?
echo "lake build rc $rc"
tail -n 3 "$OUT/full.log"
echo "warnings: $(grep -c 'warning' "$OUT/full.log")"
echo "errors: $(grep -c 'error' "$OUT/full.log")"
echo "sorry: $(grep -c 'sorry' "$OUT/full.log")"
if [ $rc -ne 0 ]; then
  grep -E "error|warning" "$OUT/full.log" | grep -v "^trace" | head -n 40
  echo "build failed: the audit and the regressions are skipped"
  exit 1
fi
echo "== axiom audit =="
python3 -I "$OUT/gen_axioms.py" "$L" "$OUT/axioms_l14.lean"
"$LAKE" -d "$WT/formal" env lean "$OUT/axioms_l14.lean" > "$OUT/axioms.log" 2>&1
arc=$?
echo "axioms rc $arc"
echo "declarations audited: $(grep -c 'depends on axioms\|does not depend on any axioms' "$OUT/axioms.log")"
echo "sorryAx: $(grep -c 'sorryAx' "$OUT/axioms.log")"
echo "ofReduceBool: $(grep -c 'ofReduceBool' "$OUT/axioms.log")"
echo "other axioms: $(grep 'depends on axioms' "$OUT/axioms.log" | grep -v -E "\[(propext|Classical.choice|Quot.sound)(, (propext|Classical.choice|Quot.sound))*\]" | wc -l | tr -d ' ')"
grep -oE "axioms: \[[^]]*\]" "$OUT/axioms.log" | sort | uniq -c
echo "== source scan of the L14 files =="
grep -n -E '\bsorry\b|\baxiom\b|native_decide|admit|maxRecDepth|maxHeartbeats|implemented_by|@\[extern|\bextern\b|bv_decide|ofReduceBool' $FILES || echo "none"
echo "== the library root imports the L14 files =="
for m in ZKW16Prog ZKW16Step ZKW16View ZKW16Block ZKW16Hyb; do grep -n "ZK60Formal.$m\$" "$WT/formal/ZK60Formal.lean" || echo "MISSING $m"; done
echo "== regression: L6Check on the committed L6 corpus =="
"$LAKE" -d "$WT/formal" env lean --run "$L/L6Check.lean" "$O6/corpus.txt" > "$OUT/l6check_regression.log" 2>&1
echo "L6Check rc $?"
tail -n 1 "$OUT/l6check_regression.log"
echo "== regression: L5Check on the committed L5 corpus =="
"$LAKE" -d "$WT/formal" env lean --run "$L/L5Check.lean" "$O5/corpus.txt" > "$OUT/l5check_regression.log" 2>&1
echo "L5Check rc $?"
tail -n 1 "$OUT/l5check_regression.log"
echo "== regression: L11Check on the committed L11 corpus =="
"$LAKE" -d "$WT/formal" env lean --run "$L/L11Check.lean" "$O11/corpus.txt" > "$OUT/l11check_regression.log" 2>&1
echo "L11Check rc $?"
tail -n 1 "$OUT/l11check_regression.log"
echo "== done =="
[ $rc -eq 0 ] && [ $arc -eq 0 ]
