#!/bin/bash
# D63 Lean lane L29 (2026-11-07, the executable stage IN-C / OUT-C verifiers, the stages' completeness, the oracle
# form's transcript programs): the full Lean build, the axiom audit of every theorem of the L29 library files, the
# source scan, the root imports, the regressions L6Check, L5Check, the fixture L1 check, L11Check, StageCheckOutC and
# ProtocolClassifyCheck (the arguments of results/zk60_lean_l15_20261107/check_l15merge.sh and
# results/zk60_lean_l18_20261107/check_l18merge.sh), and this lane's checker StageVerifyExecCheck on the committed corpus
# (with the two stage segments' bytes when they are present outside the repository), as ONE guarded job. Run through
# run_guarded.py (the zk60 resource guard, class cpu).
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a5e8655cfe4c9f794
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
OUT=$WT/results/zk60_lean_l29_20261107
SCR=/Users/victorrielly/zk60-artifacts/resume-20261109/l29
O6=$WT/results/zk60_lean_l6_20261106
O5=$WT/results/zk60_lean_l5_20261106
O11=$WT/results/zk60_lean_l11_20261107
O15=$WT/results/zk60_lean_l15_20261107
O18=$WT/results/zk60_lean_l18_20261107
R1=$WT/results/zk60_lean_l1l2_20261106
V=$WT/ops/zkp-mvp/gpu-metal/hashline/src/private_block/r13_vectors
L=$WT/formal/ZK60Formal
MODS="StageVerifyExecLay StageVerifyExecInC StageVerifyExecOutC StageVerifyExec StageVerifyExecComplete StageVerifyExecAssemble HonestOracleProg"
FILES=""
for m in $MODS; do FILES="$FILES $L/$m.lean"; done
FILES="$FILES $L/StageVerifyExecCheck.lean"
echo "== lake build (full) =="
"$LAKE" -d "$WT/formal" build > "$OUT/full.log" 2>&1
rc=$?
echo "lake build rc $rc"
tail -n 3 "$OUT/full.log"
echo "warnings: $(grep -c 'warning' "$OUT/full.log")"
echo "errors: $(grep -c 'error' "$OUT/full.log")"
echo "sorry: $(grep -c 'sorry' "$OUT/full.log")"
echo "== axiom audit =="
python3 -I "$OUT/gen_axioms.py" "$L" "$OUT/axioms_l29.lean"
"$LAKE" -d "$WT/formal" env lean "$OUT/axioms_l29.lean" > "$OUT/axioms.log" 2>&1
arc=$?
echo "axioms rc $arc"
echo "declarations audited: $(grep -c 'depends on axioms\|does not depend on any axioms' "$OUT/axioms.log")"
echo "sorryAx: $(grep -c 'sorryAx' "$OUT/axioms.log")"
echo "ofReduceBool: $(grep -c 'ofReduceBool' "$OUT/axioms.log")"
echo "other axioms: $(grep 'depends on axioms' "$OUT/axioms.log" | grep -v -E "\[(propext|Classical.choice|Quot.sound)(, (propext|Classical.choice|Quot.sound))*\]" | wc -l | tr -d ' ')"
grep -oE "axioms: \[[^]]*\]" "$OUT/axioms.log" | sort | uniq -c
echo "== source scan of the L29 files =="
grep -n -E '\bsorry\b|\baxiom\b|native_decide|admit|maxRecDepth|maxHeartbeats|implemented_by|@\[extern|\bextern\b|bv_decide|ofReduceBool' $FILES || echo "none"
echo "== the library root imports the L29 library files; the checker (main) is not imported =="
for m in $MODS; do grep -n "ZK60Formal.$m\$" "$WT/formal/ZK60Formal.lean" || echo "MISSING $m"; done
grep -n "StageVerifyExecCheck" "$WT/formal/ZK60Formal.lean" && echo "THE CHECKER IS IMPORTED" || echo "checker not imported"
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
echo "== regression: StageCheckOutC on the committed L15 corpus =="
"$LAKE" -d "$WT/formal" env lean --run "$L/StageCheckOutC.lean" "$O15/corpus.txt" > "$OUT/stagecheckoutc_regression.log" 2>&1
c15=$?
tail -n 1 "$OUT/stagecheckoutc_regression.log"
echo "== regression: ProtocolClassifyCheck on the committed L18 corpus =="
"$LAKE" -d "$WT/formal" env lean --run "$L/ProtocolClassifyCheck.lean" "$O18/corpus.txt" > "$OUT/protocolclassifycheck_regression.log" 2>&1
c18=$?
tail -n 1 "$OUT/protocolclassifycheck_regression.log"
echo "== StageVerifyExecCheck on the committed L29 corpus (with the segments' bytes when present) =="
if [ -f "$SCR/l29_seg_in.bin" ] && [ -f "$SCR/l29_seg_out.bin" ]; then
  "$LAKE" -d "$WT/formal" env lean --run "$L/StageVerifyExecCheck.lean" "$OUT/corpus.txt" "$SCR/l29_seg_in.bin" "$SCR/l29_seg_out.bin" > "$OUT/l29check.log" 2>&1
else
  "$LAKE" -d "$WT/formal" env lean --run "$L/StageVerifyExecCheck.lean" "$OUT/corpus.txt" > "$OUT/l29check.log" 2>&1
fi
c29=$?
grep -E "checks, [0-9]+ failed" "$OUT/l29check.log"
g6=1; grep -q '^L6Check: 1206 checks, 0 failed$' "$OUT/l6check_regression.log" && g6=0
g5=1; grep -q '^L5Check: 5553 checks, 0 failed$' "$OUT/l5check_regression.log" && g5=0
g1=1; grep -q '101956 checks, 0 failed' "$OUT/l1check_regression.log" && g1=0
g11=1; grep -q '404 checks, 0 failed' "$OUT/l11check_regression.log" && g11=0
g15=1; grep -q '^StageCheckOutC: 81 checks, 0 failed$' "$OUT/stagecheckoutc_regression.log" && g15=0
g18=1; grep -q '^ProtocolClassifyCheck: 31 checks, 0 failed$' "$OUT/protocolclassifycheck_regression.log" && g18=0
g29=1; grep -q '^StageVerifyExecCheck: [0-9]* checks, 0 failed$' "$OUT/l29check.log" && g29=0
echo "verdicts: build $rc, axioms $arc, L6 $c6/$g6, L5 $c5/$g5, L1 $c1/$g1, L11 $c11/$g11, L15 $c15/$g15, L18 $c18/$g18, L29 $c29/$g29 (0 = as required)"
[ $rc -eq 0 ] && [ $arc -eq 0 ] && [ $c6 -eq 0 ] && [ $c5 -eq 0 ] && [ $g6 -eq 0 ] && [ $g5 -eq 0 ] && [ $c1 -eq 0 ] \
  && [ $g1 -eq 0 ] && [ $c11 -eq 0 ] && [ $g11 -eq 0 ] && [ $c15 -eq 0 ] && [ $g15 -eq 0 ] && [ $c18 -eq 0 ] \
  && [ $g18 -eq 0 ] && [ $c29 -eq 0 ] && [ $g29 -eq 0 ]
