#!/bin/bash
# D63 Lean lane L17 (2026-11-07): the build-only rerun on the final tree after check_l17.sh's run 1 (ShapeR13.lean's
# one linter warning removed, a `<;>` that applied to one goal; and its prose reworded so that the source scan's
# `admit` pattern no longer matches the words "admitted"/"admits"; no statement changed): the full Lean build, the
# axiom audit of every L17 theorem, the source scan, the root imports. Run through run_guarded.py (class cpu).
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a1625b90fca168135
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
OUT=$WT/results/zk60_lean_l17_20261107
L=$WT/formal/ZK60Formal
LIB="ExecBlockR13 SlotR13 OpeningR13 LayoutR13 ShapeR13"
FILES="$L/ExecBlockR13.lean $L/SlotR13.lean $L/OpeningR13.lean $L/LayoutR13.lean $L/ShapeR13.lean $L/CheckR13Block.lean $L/CheckR13Slots.lean $L/CheckR13Open.lean"
echo "== lake build (full) =="
"$LAKE" -d "$WT/formal" build > "$OUT/full3.log" 2>&1
rc=$?
echo "lake build rc $rc"
tail -n 3 "$OUT/full3.log"
echo "warnings: $(grep -c 'warning' "$OUT/full3.log")"
echo "errors: $(grep -c 'error' "$OUT/full3.log")"
echo "sorry: $(grep -c 'sorry' "$OUT/full3.log")"
echo "== axiom audit =="
python3 -I "$OUT/gen_axioms.py" "$L" "$OUT/axioms_l17.lean"
"$LAKE" -d "$WT/formal" env lean "$OUT/axioms_l17.lean" > "$OUT/axioms.log" 2>&1
arc=$?
echo "axioms rc $arc"
echo "declarations audited: $(grep -c 'depends on axioms\|does not depend on any axioms' "$OUT/axioms.log")"
echo "sorryAx: $(grep -c 'sorryAx' "$OUT/axioms.log")"
echo "ofReduceBool: $(grep -c 'ofReduceBool' "$OUT/axioms.log")"
echo "other axioms: $(grep 'depends on axioms' "$OUT/axioms.log" | grep -v -E "\[(propext|Classical.choice|Quot.sound)(, (propext|Classical.choice|Quot.sound))*\]" | wc -l | tr -d ' ')"
grep -oE "axioms: \[[^]]*\]" "$OUT/axioms.log" | sort | uniq -c
echo "no axioms: $(grep -c 'does not depend on any axioms' "$OUT/axioms.log")"
echo "== source scan of the L17 files =="
grep -n -E '\bsorry\b|\baxiom\b|native_decide|admit|maxRecDepth|maxHeartbeats|implemented_by|@\[extern|\bextern\b|bv_decide|ofReduceBool' $FILES || echo "none"
echo "== the library root imports the L17 library files, not the checkers =="
for m in $LIB; do grep -n "ZK60Formal.$m\$" "$WT/formal/ZK60Formal.lean" || echo "MISSING $m"; done
grep -n "ZK60Formal.CheckR13" "$WT/formal/ZK60Formal.lean" && echo "UNEXPECTED: a checker is imported" || echo "the checkers (main) are not imported"
[ $rc -eq 0 ] && [ $arc -eq 0 ]
