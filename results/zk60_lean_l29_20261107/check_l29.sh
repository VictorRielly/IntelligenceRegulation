#!/bin/bash
# D63 Lean lane L29 (2026-11-07, resumed 2026-11-09; the executable stage IN-C / OUT-C verifiers, the stages'
# completeness, the oracle form's transcript programs and the honest slot loop as one): the full Lean build, the axiom
# audit of every theorem of the L29 library files, the source scan, the root imports, the regressions L6Check, L5Check,
# the fixture L1 check, L11Check, StageCheckOutC and ProtocolClassifyCheck (the arguments of
# results/zk60_lean_l15_20261107/check_l15merge.sh and results/zk60_lean_l18_20261107/check_l18merge.sh), this lane's
# checker StageVerifyExecCheck on the committed corpus (with the two stage segments' bytes of the SAME export when they
# are present outside the repository: the corpus records each segment's length and BLAKE3, which the checker compares),
# and its negative control (mutate_corpus.py: seven single changes, each must be caught), as ONE guarded job. Run
# through run_guarded.py (the zk60 resource guard, class cpu).
WT=${L29_WT:-/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a5e8655cfe4c9f794}
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
OUT=$WT/results/zk60_lean_l29_20261107
SCR=${L29_SCR:-/Users/victorrielly/zk60-artifacts/resume-20261109}/l29
O6=$WT/results/zk60_lean_l6_20261106
O5=$WT/results/zk60_lean_l5_20261106
O11=$WT/results/zk60_lean_l11_20261107
O15=$WT/results/zk60_lean_l15_20261107
O18=$WT/results/zk60_lean_l18_20261107
R1=$WT/results/zk60_lean_l1l2_20261106
V=$WT/ops/zkp-mvp/gpu-metal/hashline/src/private_block/r13_vectors
L=$WT/formal/ZK60Formal
MODS="StageVerifyExecLay StageVerifyExecInC StageVerifyExecOutC StageVerifyExec StageVerifyExecComplete StageVerifyExecAssemble HonestOracleProg HonestOracleSlots"
FILES=""
for m in $MODS; do FILES="$FILES $L/$m.lean"; done
FILES="$FILES $L/StageVerifyExecCheck.lean"
ulimit -s 65520
start=$(date +%s)
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
other=$(grep 'depends on axioms' "$OUT/axioms.log" | grep -v -E "\[(propext|Classical.choice|Quot.sound)(, (propext|Classical.choice|Quot.sound))*\]" | wc -l | tr -d ' ')
echo "other axioms: $other"
grep -oE "axioms: \[[^]]*\]" "$OUT/axioms.log" | sort | uniq -c
echo "on no axiom: $(grep -c 'does not depend on any axioms' "$OUT/axioms.log")"
echo "== source scan of the L29 files =="
grep -n -E '\bsorry\b|\baxiom\b|native_decide|admit|maxRecDepth|maxHeartbeats|implemented_by|@\[extern|\bextern\b|bv_decide|ofReduceBool' $FILES > "$OUT/scan.log"
src=$?
[ $src -eq 1 ] && echo "none" || cat "$OUT/scan.log"
echo "== the library root imports the L29 library files; the checker (main) is not imported =="
imp=0
for m in $MODS; do grep -n "ZK60Formal.$m\$" "$WT/formal/ZK60Formal.lean" || { echo "MISSING $m"; imp=1; }; done
grep -n "StageVerifyExecCheck" "$WT/formal/ZK60Formal.lean" && { echo "THE CHECKER IS IMPORTED"; imp=1; } || echo "checker not imported"
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
SEGS=""
if [ -f "$SCR/l29_seg_in.bin" ] && [ -f "$SCR/l29_seg_out.bin" ]; then SEGS="$SCR/l29_seg_in.bin $SCR/l29_seg_out.bin"; fi
[ -n "$SEGS" ] && echo "== StageVerifyExecCheck on the committed L29 corpus, WITH the segments' bytes ==" \
  || echo "== StageVerifyExecCheck on the committed L29 corpus, WITHOUT the segments' bytes (DECODE / VERIFY not run) =="
t0=$(date +%s)
"$LAKE" -d "$WT/formal" env lean --run "$L/StageVerifyExecCheck.lean" "$OUT/corpus.txt" $SEGS > "$OUT/l29check.log" 2>&1
c29=$?
grep -E "^FAIL|^[A-Z]+: [0-9]+ checks, [0-9]+ failed|^StageVerifyExecCheck|^\(no segment" "$OUT/l29check.log"
echo "StageVerifyExecCheck rc $c29, $(( $(date +%s) - t0 )) s"
echo "== negative control: seven single changes to the corpus =="
python3 -I "$OUT/mutate_corpus.py" "$OUT/corpus.txt" "$SCR/l29_mutated.txt"
"$LAKE" -d "$WT/formal" env lean --run "$L/StageVerifyExecCheck.lean" "$SCR/l29_mutated.txt" $SEGS > "$OUT/negative_control.log" 2>&1
cn=$?
grep -E "^FAIL|^StageVerifyExecCheck" "$OUT/negative_control.log"
echo "negative control rc $cn (nonzero required)"
g6=1; grep -q '^L6Check: 1206 checks, 0 failed$' "$OUT/l6check_regression.log" && g6=0
g5=1; grep -q '^L5Check: 5553 checks, 0 failed$' "$OUT/l5check_regression.log" && g5=0
g1=1; grep -q '101956 checks, 0 failed' "$OUT/l1check_regression.log" && g1=0
g11=1; grep -q '404 checks, 0 failed' "$OUT/l11check_regression.log" && g11=0
g15=1; grep -q '^StageCheckOutC: 81 checks, 0 failed$' "$OUT/stagecheckoutc_regression.log" && g15=0
g18=1; grep -q '^ProtocolClassifyCheck: 31 checks, 0 failed$' "$OUT/protocolclassifycheck_regression.log" && g18=0
g29=1; grep -q '^StageVerifyExecCheck: [0-9]* checks, 0 failed$' "$OUT/l29check.log" && g29=0
want=5; [ -n "$SEGS" ] && want=8
gn=1; [ $cn -ne 0 ] && grep -q "^StageVerifyExecCheck: [0-9]* checks, $want failed\$" "$OUT/negative_control.log" && gn=0
gw=1; [ "$(grep -c 'warning' "$OUT/full.log")" = "0" ] && [ "$(grep -c 'sorry' "$OUT/full.log")" = "0" ] && gw=0
ga=1; [ "$other" = "0" ] && [ "$(grep -c 'sorryAx' "$OUT/axioms.log")" = "0" ] && [ "$(grep -c 'ofReduceBool' "$OUT/axioms.log")" = "0" ] && ga=0
gs=1; [ $src -eq 1 ] && gs=0
echo "verdicts: build $rc, no warning or sorry $gw, axioms $arc/$ga, scan $gs, imports $imp, L6 $c6/$g6, L5 $c5/$g5, L1 $c1/$g1, L11 $c11/$g11, L15 $c15/$g15, L18 $c18/$g18, L29 $c29/$g29, negative control (want $want failed) $gn (0 = as required), $(( $(date +%s) - start )) s"
[ $rc -eq 0 ] && [ $gw -eq 0 ] && [ $arc -eq 0 ] && [ $ga -eq 0 ] && [ $gs -eq 0 ] && [ $imp -eq 0 ] && [ $c6 -eq 0 ] \
  && [ $c5 -eq 0 ] && [ $g6 -eq 0 ] && [ $g5 -eq 0 ] && [ $c1 -eq 0 ] && [ $g1 -eq 0 ] && [ $c11 -eq 0 ] && [ $g11 -eq 0 ] \
  && [ $c15 -eq 0 ] && [ $g15 -eq 0 ] && [ $c18 -eq 0 ] && [ $g18 -eq 0 ] && [ $c29 -eq 0 ] && [ $g29 -eq 0 ] && [ $gn -eq 0 ]
