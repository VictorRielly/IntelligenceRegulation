#!/bin/bash
# D63 Lean lane L12 (2026-11-07, the token stages' knowledge-soundness parts): the full Lean build, the axiom audit
# of every theorem of the seven L12 files, the source scan, the root imports, and as regressions L6Check, L5Check and
# the fixture L1 check on their committed corpora, as ONE guarded job. Run through run_guarded.py (the zk60 resource
# guard, class cpu). L12 adds no Rust and no checker of its own (deliverable 4 was not reached). The arguments of the
# regressions are results/zk60_lean_l8_20261106/check_l8merge.sh's.
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-ab31b1765545a6bd4
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
OUT=$WT/results/zk60_lean_l12_20261107
O6=$WT/results/zk60_lean_l6_20261106
O5=$WT/results/zk60_lean_l5_20261106
R1=$WT/results/zk60_lean_l1l2_20261106
V=$WT/ops/zkp-mvp/gpu-metal/hashline/src/private_block/r13_vectors
FILES="$WT/formal/ZK60Formal/StageExtractCore.lean $WT/formal/ZK60Formal/StageInExtract.lean $WT/formal/ZK60Formal/StageInExtractSlots.lean $WT/formal/ZK60Formal/StageOutCExtract.lean $WT/formal/ZK60Formal/StageOutCExtractSlots.lean $WT/formal/ZK60Formal/StageOutExtract.lean $WT/formal/ZK60Formal/StageRunExtract.lean"
echo "== lake build (full) =="
"$LAKE" -d "$WT/formal" build > "$OUT/full.log" 2>&1
rc=$?
echo "lake build rc $rc"
tail -n 3 "$OUT/full.log"
echo "warnings: $(grep -c 'warning' "$OUT/full.log")"
echo "errors: $(grep -c 'error' "$OUT/full.log")"
echo "sorry: $(grep -c 'sorry' "$OUT/full.log")"
echo "== axiom audit =="
python3 -I "$OUT/gen_axioms.py" "$WT/formal/ZK60Formal" "$OUT/axioms_l12.lean"
"$LAKE" -d "$WT/formal" env lean "$OUT/axioms_l12.lean" > "$OUT/axioms.log" 2>&1
arc=$?
echo "axioms rc $arc"
echo "declarations audited: $(grep -c 'depends on axioms\|does not depend on any axioms' "$OUT/axioms.log")"
echo "sorryAx: $(grep -c 'sorryAx' "$OUT/axioms.log")"
echo "ofReduceBool: $(grep -c 'ofReduceBool' "$OUT/axioms.log")"
echo "other axioms: $(grep 'depends on axioms' "$OUT/axioms.log" | grep -v -E "\[(propext|Classical.choice|Quot.sound)(, (propext|Classical.choice|Quot.sound))*\]" | wc -l | tr -d ' ')"
grep -oE "axioms: \[[^]]*\]" "$OUT/axioms.log" | sort | uniq -c
echo "== source scan of the L12 files =="
grep -n -E '\bsorry\b|\baxiom\b|native_decide|admit|maxRecDepth|maxHeartbeats|implemented_by|@\[extern|\bextern\b|bv_decide|ofReduceBool' $FILES || echo "none"
echo "== the library root imports the L12 files =="
for m in StageExtractCore StageInExtract StageInExtractSlots StageOutCExtract StageOutCExtractSlots StageOutExtract StageRunExtract; do
  grep -n "ZK60Formal.$m\$" "$WT/formal/ZK60Formal.lean" || echo "MISSING $m"
done
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
echo "== regression: the fixture L1 check =="
"$LAKE" -d "$WT/formal" env lean --run "$WT/formal/ZK60Formal/L1Check.lean" "$V/block_fixture_t32.tsv" \
  "$V/block_trace_low_h24_t32.tsv" "$V/block_trace_low_t32.tsv" "$R1/rust_fixture_trace.tsv" "$V/r13_requant_vectors.tsv" \
  > "$OUT/l1check_regression.log" 2>&1
c1=$?
tail -n 1 "$OUT/l1check_regression.log"
echo "L1Check rc $c1"
g6=1
grep -q '^L6Check: 1206 checks, 0 failed$' "$OUT/l6check_regression.log" && g6=0
g5=1
grep -q '^L5Check: 5553 checks, 0 failed$' "$OUT/l5check_regression.log" && g5=0
g1=1
tail -n 1 "$OUT/l1check_regression.log" | grep -q '101956 checks, 0 failed' && g1=0
echo "regression verdicts: L6 $g6, L5 $g5, L1 $g1 (0 = the committed count with 0 failed)"
[ $rc -eq 0 ] && [ $arc -eq 0 ] && [ $c6 -eq 0 ] && [ $c5 -eq 0 ] && [ $c1 -eq 0 ] && [ $g6 -eq 0 ] && [ $g5 -eq 0 ] && [ $g1 -eq 0 ]
