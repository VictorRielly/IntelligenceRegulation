#!/bin/bash
# D63 step L19 Lean lane (2026-11-07, zero knowledge: the layout links and the sharper count): the full Lean build, the
# axiom audit of every theorem of the seven L19 files, the source scan, the root imports, and the regressions L6Check,
# L5Check, the fixture L1 check and L11Check on their committed corpora (the arguments of
# results/zk60_lean_l14_20261107/check_l14merge.sh), as ONE guarded job. Run through run_guarded.py (the zk60 resource
# guard, class cpu).
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a7c9689a93e645f06
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
OUT=$WT/results/zk60_lean_l19_20261107
O6=$WT/results/zk60_lean_l6_20261106
O5=$WT/results/zk60_lean_l5_20261106
O11=$WT/results/zk60_lean_l11_20261107
R1=$WT/results/zk60_lean_l1l2_20261106
V=$WT/ops/zkp-mvp/gpu-metal/hashline/src/private_block/r13_vectors
L=$WT/formal/ZK60Formal
FILES="$L/ZKLinks.lean $L/ZKLinksM.lean $L/ZKLinksRun.lean $L/ZKCount.lean $L/ZKCountStep.lean $L/ZKCountHyb.lean $L/ZKCountBudget.lean"
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
python3 -I "$OUT/gen_axioms.py" "$L" "$OUT/axioms_l19.lean"
"$LAKE" -d "$WT/formal" env lean "$OUT/axioms_l19.lean" > "$OUT/axioms.log" 2>&1
arc=$?
echo "axioms rc $arc"
echo "declarations audited: $(grep -c 'depends on axioms\|does not depend on any axioms' "$OUT/axioms.log")"
echo "sorryAx: $(grep -c 'sorryAx' "$OUT/axioms.log")"
echo "ofReduceBool: $(grep -c 'ofReduceBool' "$OUT/axioms.log")"
echo "other axioms: $(grep 'depends on axioms' "$OUT/axioms.log" | grep -v -E "\[(propext|Classical.choice|Quot.sound)(, (propext|Classical.choice|Quot.sound))*\]" | wc -l | tr -d ' ')"
grep -oE "axioms: \[[^]]*\]" "$OUT/axioms.log" | sort | uniq -c
echo "== source scan of the L19 files =="
grep -n -E '\bsorry\b|\baxiom\b|native_decide|admit|maxRecDepth|maxHeartbeats|implemented_by|@\[extern|\bextern\b|bv_decide|ofReduceBool' $FILES || echo "none"
echo "== the library root imports the L19 files =="
for m in ZKLinks ZKLinksM ZKLinksRun ZKCount ZKCountStep ZKCountHyb ZKCountBudget; do grep -n "ZK60Formal.$m\$" "$WT/formal/ZK60Formal.lean" || echo "MISSING $m"; done
ulimit -s 65520
echo "== regression: L6Check on the committed L6 corpus =="
"$LAKE" -d "$WT/formal" env lean --run "$L/L6Check.lean" "$O6/corpus.txt" > "$OUT/l6check_regression.log" 2>&1
c6=$?
tail -n 1 "$OUT/l6check_regression.log"
echo "== regression: L5Check on the committed L5 corpus =="
"$LAKE" -d "$WT/formal" env lean --run "$L/L5Check.lean" "$O5/corpus.txt" > "$OUT/l5check_regression.log" 2>&1
c5=$?
tail -n 1 "$OUT/l5check_regression.log"
echo "== regression: the fixture L1 check =="
"$LAKE" -d "$WT/formal" env lean --run "$L/L1Check.lean" "$V/block_fixture_t32.tsv" "$V/block_trace_low_h24_t32.tsv" \
  "$V/block_trace_low_t32.tsv" "$R1/rust_fixture_trace.tsv" "$V/r13_requant_vectors.tsv" > "$OUT/l1check_regression.log" 2>&1
c1=$?
tail -n 1 "$OUT/l1check_regression.log"
echo "== regression: L11Check on the W16R2 rung corpus =="
"$LAKE" -d "$WT/formal" env lean --run "$L/L11Check.lean" "$O11/corpus.txt" > "$OUT/l11check_regression.log" 2>&1
c11=$?
tail -n 1 "$OUT/l11check_regression.log"
g6=1; grep -q '^L6Check: 1206 checks, 0 failed$' "$OUT/l6check_regression.log" && g6=0
g5=1; grep -q '^L5Check: 5553 checks, 0 failed$' "$OUT/l5check_regression.log" && g5=0
g1=1; grep -q '101956 checks, 0 failed' "$OUT/l1check_regression.log" && g1=0
g11=1; grep -q '^L11Check: 404 checks, 0 failed$' "$OUT/l11check_regression.log" && g11=0
echo "verdicts: build $rc, axioms $arc, L6 $c6/$g6, L5 $c5/$g5, L1 $c1/$g1, L11 $c11/$g11 (0 = as required)"
[ $rc -eq 0 ] && [ $arc -eq 0 ] && [ $c6 -eq 0 ] && [ $c5 -eq 0 ] && [ $g6 -eq 0 ] && [ $g5 -eq 0 ] && [ $c1 -eq 0 ] \
  && [ $g1 -eq 0 ] && [ $c11 -eq 0 ] && [ $g11 -eq 0 ]
