#!/bin/bash
# D63 lane L23 (2026-11-07): the full Lean build, the axiom audit of every theorem of the ten L23 files, the source
# scan, the root imports, and the regressions (L6Check and L5Check on their committed corpora, L11Check on L11's
# committed W16R2 rung corpus, the fixture L1 check, SlotW16BuildCheck on L13's layout and L11's corpus; arguments as in
# results/zk60_lean_l21_20261107/check_l21.sh and results/zk60_lean_l13_20261107/check_l13merge.sh) and the agreement check
# of M's functionals (mcheck.sh, CoverW16MCheck.lean), as ONE guarded job.
# Run through run_guarded.py (the zk60 resource guard, class cpu).
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-ad9d55551b2c8d9df
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
OUT=$WT/results/zk60_lean_l23_20261107
O6=$WT/results/zk60_lean_l6_20261106
O5=$WT/results/zk60_lean_l5_20261106
O11=$WT/results/zk60_lean_l11_20261107
O13=$WT/results/zk60_lean_l13_20261107
R1=$WT/results/zk60_lean_l1l2_20261106
V=$WT/ops/zkp-mvp/gpu-metal/hashline/src/private_block/r13_vectors
L=$WT/formal/ZK60Formal
MODS="CoverW16 CoverW16Unmask CoverW16Target CoverW16Gen SlotPolyW16Kinds SlotPolyW16 SlotPolyW16Draw CoverW16Inst CoverW16R13 CoverW16Shapes SlotPolyW16Map SlotPolyW16Seg"
FILES="$L/CoverW16MCheck.lean"
for m in $MODS; do FILES="$FILES $L/$m.lean"; done
start=$(date +%s)
echo "== lake build of the L23 modules, one at a time =="
for m in $MODS; do
  "$LAKE" -d "$WT/formal" build ZK60Formal.$m > "$OUT/prebuild_$m.log" 2>&1
  echo "lake build ZK60Formal.$m rc $?"
done
echo "== lake build (full) =="
"$LAKE" -d "$WT/formal" build > "$OUT/full.log" 2>&1
rc=$?
echo "lake build rc $rc"
tail -n 3 "$OUT/full.log"
echo "warnings: $(grep -c 'warning' "$OUT/full.log")"
echo "errors: $(grep -c 'error' "$OUT/full.log")"
echo "sorry: $(grep -c 'sorry' "$OUT/full.log")"
echo "warnings in the L23 files: $(grep -cE 'warning: ZK60Formal/(CoverW16|SlotPolyW16)' "$OUT/full.log")"
if [ $rc -ne 0 ]; then
  grep -E 'error' "$OUT/full.log" | head -n 20
  exit 1
fi
echo "== axiom audit =="
python3 -I "$OUT/gen_axioms.py" "$L" "$OUT/axioms_l23.lean"
"$LAKE" -d "$WT/formal" env lean "$OUT/axioms_l23.lean" > "$OUT/axioms.log" 2>&1
arc=$?
echo "axioms rc $arc"
echo "declarations audited: $(grep -c 'depends on axioms\|does not depend on any axioms' "$OUT/axioms.log")"
echo "sorryAx: $(grep -c 'sorryAx' "$OUT/axioms.log")"
echo "ofReduceBool: $(grep -c 'ofReduceBool' "$OUT/axioms.log")"
echo "other axioms: $(grep 'depends on axioms' "$OUT/axioms.log" | grep -v -E "\[(propext|Classical.choice|Quot.sound)(, (propext|Classical.choice|Quot.sound))*\]" | wc -l | tr -d ' ')"
grep -oE "axioms: \[[^]]*\]" "$OUT/axioms.log" | sort | uniq -c
echo "== source scan of the L23 files =="
grep -n -E '\bsorry\b|\baxiom\b|native_decide|admit|maxRecDepth|maxHeartbeats|implemented_by|@\[extern|\bextern\b|bv_decide|ofReduceBool' $FILES || echo "none"
echo "== the library root imports the L23 files =="
for m in $MODS; do
  grep -q "^import ZK60Formal.$m\$" "$WT/formal/ZK60Formal.lean" && echo "imported: $m" || echo "MISSING: $m"
done
echo "== regression: L6Check on the committed L6 corpus =="
"$LAKE" -d "$WT/formal" env lean --run "$L/L6Check.lean" "$O6/corpus.txt" > "$OUT/l6check_regression.log" 2>&1
c6=$?
tail -n 1 "$OUT/l6check_regression.log"
echo "== regression: L5Check on the committed L5 corpus =="
"$LAKE" -d "$WT/formal" env lean --run "$L/L5Check.lean" "$O5/corpus.txt" > "$OUT/l5check_regression.log" 2>&1
c5=$?
tail -n 1 "$OUT/l5check_regression.log"
echo "== regression: L11Check on L11's committed W16R2 rung corpus =="
"$LAKE" -d "$WT/formal" env lean --run "$L/L11Check.lean" "$O11/corpus.txt" > "$OUT/l11check_regression.log" 2>&1
c11=$?
tail -n 1 "$OUT/l11check_regression.log"
echo "== regression: the fixture L1 check =="
"$LAKE" -d "$WT/formal" env lean --run "$L/L1Check.lean" "$V/block_fixture_t32.tsv" "$V/block_trace_low_h24_t32.tsv" \
  "$V/block_trace_low_t32.tsv" "$R1/rust_fixture_trace.tsv" "$V/r13_requant_vectors.tsv" > "$OUT/l1check_regression.log" 2>&1
c1=$?
tail -n 1 "$OUT/l1check_regression.log"
echo "== regression: SlotW16BuildCheck on L13's layout and L11's corpus =="
"$LAKE" -d "$WT/formal" env lean --run "$L/SlotW16BuildCheck.lean" "$O13/layout.txt" "$O11/corpus.txt" \
  > "$OUT/l13check_regression.log" 2>&1
c13=$?
tail -n 1 "$OUT/l13check_regression.log"
echo "== regression: ExecBlockCheck on L9's corpus and frame (the block verifier, slotAcc fixed by L23-1) =="
F9=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/l9merge/fork_frame.bin
( ulimit -s 65520; "$LAKE" -d "$WT/formal" env lean --run "$L/ExecBlockCheck.lean" "$WT/results/zk60_lean_l9_20261107/corpus.txt" "$F9" ) \
  > "$OUT/l9check_regression.log" 2>&1
c9=$?
tail -n 1 "$OUT/l9check_regression.log"
g9=1
grep -q '^ExecBlockCheck: 273 checks, 0 failed$' "$OUT/l9check_regression.log" && g9=0
echo "== agreement: M's functionals (weights and values) against the real W16R2 rung receipt =="
/bin/bash "$OUT/mcheck.sh" > "$OUT/mcheck.log" 2>&1
cm=$?
grep -v '^trace:' "$OUT/mcheck.log" | tail -n 1
gm=1
grep -q '^MFunCheck: [0-9]* checks, 0 failed$' "$OUT/mcheck.log" && gm=0
g6=1
grep -q '^L6Check: 1206 checks, 0 failed$' "$OUT/l6check_regression.log" && g6=0
g5=1
grep -q '^L5Check: 5553 checks, 0 failed$' "$OUT/l5check_regression.log" && g5=0
g11=1
grep -q '^L11Check: 404 checks, 0 failed$' "$OUT/l11check_regression.log" && g11=0
g1=1
grep -q '^L1 TOTAL: 101956 checks, 0 failed$' "$OUT/l1check_regression.log" && g1=0
g13=1
grep -q '^SlotW16BuildCheck: 179 checks, 0 failed$' "$OUT/l13check_regression.log" && g13=0
echo "regression verdicts: L6 $g6, L5 $g5, L11 $g11, L1 $g1, L13 $g13, L9 $g9, MFun $gm (0 = the committed count with 0 failed)"
echo "total $(( $(date +%s) - start )) s"
[ $rc -eq 0 ] && [ $arc -eq 0 ] && [ $c6 -eq 0 ] && [ $c5 -eq 0 ] && [ $c11 -eq 0 ] && [ $c1 -eq 0 ] && [ $c13 -eq 0 ] \
  && [ $g6 -eq 0 ] && [ $g5 -eq 0 ] && [ $g11 -eq 0 ] && [ $g1 -eq 0 ] && [ $g13 -eq 0 ] && [ $cm -eq 0 ] && [ $gm -eq 0 ] && [ $c9 -eq 0 ] && [ $g9 -eq 0 ]
