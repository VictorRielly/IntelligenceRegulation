#!/bin/bash
# D63 Lean lane L15 (2026-11-07, the token stages' whole-stage theorems): the full Lean build, the axiom audit of every
# theorem of the L15 library files, the source scan, the root imports, the regressions (L6Check, L5Check, the fixture
# L1 check with check_l12.sh's / check_l8merge.sh's arguments, L11Check on its committed corpus), the L15 agreement
# check on its corpus and its negative control, and hashline's R19b file census, as ONE guarded job. Run through
# run_guarded.py (the zk60 resource guard, class cpu).
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a656d67cb6858d77e
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
OUT=$WT/results/zk60_lean_l15_20261107
O6=$WT/results/zk60_lean_l6_20261106
O5=$WT/results/zk60_lean_l5_20261106
O11=$WT/results/zk60_lean_l11_20261107
R1=$WT/results/zk60_lean_l1l2_20261106
V=$WT/ops/zkp-mvp/gpu-metal/hashline/src/private_block/r13_vectors
L=$WT/formal/ZK60Formal
FILES="$L/StageOutCWhole.lean $L/StageOutWhole.lean $L/StageFS.lean $L/StageCheckDefs.lean $L/StageCheckValid.lean $L/StageCheckOutC.lean"
S=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad
mkdir -p "$S/l15"
echo "== lake build (full) =="
"$LAKE" -d "$WT/formal" build > "$OUT/full.log" 2>&1
rc=$?
echo "lake build rc $rc"
tail -n 3 "$OUT/full.log"
echo "warnings: $(grep -c 'warning' "$OUT/full.log")"
echo "errors: $(grep -c 'error' "$OUT/full.log")"
echo "sorry: $(grep -c 'sorry' "$OUT/full.log")"
echo "== axiom audit =="
python3 -I "$OUT/gen_axioms.py" "$L" "$OUT/axioms_l15.lean"
"$LAKE" -d "$WT/formal" env lean "$OUT/axioms_l15.lean" > "$OUT/axioms.log" 2>&1
arc=$?
echo "axioms rc $arc"
echo "declarations audited: $(grep -c 'depends on axioms\|does not depend on any axioms' "$OUT/axioms.log")"
echo "sorryAx: $(grep -c 'sorryAx' "$OUT/axioms.log")"
echo "ofReduceBool: $(grep -c 'ofReduceBool' "$OUT/axioms.log")"
echo "other axioms: $(grep 'depends on axioms' "$OUT/axioms.log" | grep -v -E "\[(propext|Classical.choice|Quot.sound)(, (propext|Classical.choice|Quot.sound))*\]" | wc -l | tr -d ' ')"
grep -oE "axioms: \[[^]]*\]" "$OUT/axioms.log" | sort | uniq -c
echo "== source scan of the L15 files =="
grep -n -E '\bsorry\b|\baxiom\b|native_decide|admit|maxRecDepth|maxHeartbeats|implemented_by|@\[extern|\bextern\b|bv_decide|ofReduceBool' $FILES || echo "none"
echo "== the library root imports the L15 library files =="
for m in StageOutCWhole StageOutWhole StageFS StageCheckDefs StageCheckValid; do grep -n "ZK60Formal.$m\$" "$WT/formal/ZK60Formal.lean" || echo "MISSING $m"; done
grep -n "ZK60Formal.StageCheckOutC" "$WT/formal/ZK60Formal.lean" && echo "UNEXPECTED: the checker is imported" || echo "the checker (main) is not imported"
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
echo "== regression: L11Check on the committed L11 corpus =="
"$LAKE" -d "$WT/formal" env lean --run "$L/L11Check.lean" "$O11/corpus.txt" > "$OUT/l11check_regression.log" 2>&1
c11=$?
tail -n 1 "$OUT/l11check_regression.log"
echo "== StageCheckOutC on the classifier's stage OUT-C corpus =="
"$LAKE" -d "$WT/formal" env lean --run "$L/StageCheckOutC.lean" "$OUT/corpus.txt" > "$OUT/stagecheck_full.log" 2>&1
c15=$?
grep -E "^  |StageCheckOutC|^FAILED" "$OUT/stagecheck_full.log"
echo "StageCheckOutC rc $c15"
echo "== negative control =="
python3 -I "$OUT/mutate_corpus.py" "$OUT/corpus.txt" "$S/l15/l15_mutated.txt"
"$LAKE" -d "$WT/formal" env lean --run "$L/StageCheckOutC.lean" "$S/l15/l15_mutated.txt" > "$OUT/negative_control.log" 2>&1
grep -E "^FAILED|StageCheckOutC" "$OUT/negative_control.log"
echo "== the R19b file census (hashline lib tests) =="
/opt/homebrew/bin/cargo test --release --offline --locked -j 2 --manifest-path "$WT/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml" \
  --lib r19b_every_rs_file > "$OUT/r19b.log" 2>&1
cr=$?
grep -E "^test |test result|R19b" "$OUT/r19b.log"
g6=1; grep -q '^L6Check: 1206 checks, 0 failed$' "$OUT/l6check_regression.log" && g6=0
g5=1; grep -q '^L5Check: 5553 checks, 0 failed$' "$OUT/l5check_regression.log" && g5=0
g1=1; grep -q '101956 checks, 0 failed' "$OUT/l1check_regression.log" && g1=0
g11=1; grep -q '404 checks, 0 failed' "$OUT/l11check_regression.log" && g11=0
gn=1; grep -q 'checks, 8 failed$' "$OUT/negative_control.log" && gn=0
echo "verdicts: build $rc, axioms $arc, L6 $c6/$g6, L5 $c5/$g5, L1 $c1/$g1, L11 $c11/$g11, L15 $c15, negative control $gn, r19b $cr (0 = as required)"
[ $rc -eq 0 ] && [ $arc -eq 0 ] && [ $c6 -eq 0 ] && [ $c5 -eq 0 ] && [ $g6 -eq 0 ] && [ $g5 -eq 0 ] && [ $c1 -eq 0 ] \
  && [ $g1 -eq 0 ] && [ $c11 -eq 0 ] && [ $g11 -eq 0 ] && [ $c15 -eq 0 ] && [ $gn -eq 0 ] && [ $cr -eq 0 ]
