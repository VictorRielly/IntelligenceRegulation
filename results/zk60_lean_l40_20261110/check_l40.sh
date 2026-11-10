#!/bin/bash
# D63 lane L40 (2026-11-10): the full Lean build (the L40 modules first, one at a time), the axiom audit of every
# theorem, definition, abbreviation, structure, class and instance of the L40 library files, the source scan, the root
# imports, the lane's two checkers (RunShapeCheck: the approved block run on the committed R13 trace fixture, with its
# negative control; l40_shield_export.py: the Shieldstral calibrations and public data against the app's verifier export,
# with its negative control), and the regressions (L6Check, L5Check, L11Check, the fixture L1 check; arguments as in
# results/zk60_lean_l26_20261107/check_l26.sh), as ONE guarded job. Run through run_guarded.py (the zk60 resource guard,
# class cpu). Its exit code is 0 only when every verdict below is green.
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a87ee5a3c81d92fe4
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
OUT=$WT/results/zk60_lean_l40_20261110
O6=$WT/results/zk60_lean_l6_20261106
O5=$WT/results/zk60_lean_l5_20261106
O11=$WT/results/zk60_lean_l11_20261107
R1=$WT/results/zk60_lean_l1l2_20261106
V=$WT/ops/zkp-mvp/gpu-metal/hashline/src/private_block/r13_vectors
L=$WT/formal/ZK60Formal
BASE=14d9d748
MODS="RunShape RunShapeShield RunShapeExec RunShapeProtocol RunShapeGate RunShapeShieldOpen RunShapeLeak RunShapeGateL"
FILES="$L/RunShape.lean $L/RunShapeShield.lean $L/RunShapeExec.lean $L/RunShapeProtocol.lean $L/RunShapeGate.lean $L/RunShapeShieldOpen.lean $L/RunShapeLeak.lean $L/RunShapeGateL.lean $L/RunShapeCheck.lean"
start=$(date +%s)
echo "== lake build of the L40 modules, one at a time =="
for m in $MODS; do
  "$LAKE" -d "$WT/formal" build ZK60Formal.$m > "$OUT/prebuild_$m.log" 2>&1
  echo "lake build ZK60Formal.$m rc $?"
done
echo "== lake build (full) =="
"$LAKE" -d "$WT/formal" build > "$OUT/full.log" 2>&1
rc=$?
echo "lake build rc $rc"
tail -n 2 "$OUT/full.log"
nw=$(grep -c 'warning' "$OUT/full.log")
echo "warnings: $nw"
echo "errors: $(grep -c 'error' "$OUT/full.log")"
echo "sorry: $(grep -c 'sorry' "$OUT/full.log")"
nwp=0
for m in $MODS; do
  nwp=$(( nwp + $(grep -c 'warning' "$OUT/prebuild_$m.log") ))
done
echo "warnings in the L40 modules' own builds: $nwp"
if [ $rc -ne 0 ]; then
  grep -E 'error' "$OUT/full.log" | head -n 20
  exit 1
fi
echo "== axiom audit =="
gen=$(python3 -I "$OUT/gen_axioms.py" "$L" "$OUT/axioms_l40.lean" $MODS)
echo "$gen"
ng=${gen%% *}
"$LAKE" -d "$WT/formal" env lean "$OUT/axioms_l40.lean" > "$OUT/axioms.log" 2>&1
arc=$?
echo "axioms rc $arc"
awk '/^ /{printf "%s", $0; next} {if (NR>1) printf "\n"; printf "%s", $0} END{printf "\n"}' "$OUT/axioms.log" \
  > "$OUT/axioms_flat.log"
na=$(grep -c 'depends on axioms\|does not depend on any axioms' "$OUT/axioms_flat.log")
echo "declarations audited: $na (generated: $ng)"
echo "no axiom at all: $(grep -c 'does not depend on any axioms' "$OUT/axioms_flat.log")"
nsa=$(grep -c 'sorryAx' "$OUT/axioms_flat.log")
echo "sorryAx: $nsa"
nrb=$(grep -c 'ofReduceBool' "$OUT/axioms_flat.log")
echo "ofReduceBool: $nrb"
oth=$(grep 'depends on axioms' "$OUT/axioms_flat.log" \
  | grep -v -c -E "\[(propext|Classical.choice|Quot.sound)(, (propext|Classical.choice|Quot.sound))*\]$")
echo "other axioms: $oth"
nel=$(grep -c -v 'depends on axioms\|does not depend on any axioms' "$OUT/axioms_flat.log")
echo "lines that are not a report: $nel"
grep -oE "axioms: \[[^]]*\]" "$OUT/axioms_flat.log" | sort | uniq -c
echo "== source scan of the L40 files =="
scan=0
grep -n -E '\bsorry\b|\baxiom\b|native_decide|admit|maxRecDepth|maxHeartbeats|implemented_by|@\[extern|\bextern\b|bv_decide|ofReduceBool' $FILES \
  && scan=1 || echo "none"
echo "== the library root imports the L40 library files, not the checker =="
imp=0
for m in $MODS; do
  if grep -q "^import ZK60Formal.$m\$" "$WT/formal/ZK60Formal.lean"; then echo "imported: $m"; else echo "MISSING: $m"; imp=1; fi
done
if grep -q "^import ZK60Formal.RunShapeCheck\$" "$WT/formal/ZK60Formal.lean"; then echo "CHECKER IMPORTED"; imp=1; else echo "checker not imported"; fi
echo "== unchanged: Statements.lean and every existing Lean file against the lane's base $BASE =="
unch=0
git -C "$WT" diff --quiet $BASE -- formal/ZK60Formal/Statements.lean && echo "Statements.lean unchanged" \
  || { echo "CHANGED"; unch=1; }
nmod=$(git -C "$WT" diff --name-only --diff-filter=MDR $BASE -- formal | grep -v -c '^formal/ZK60Formal.lean$')
echo "existing files under formal/ modified, deleted or renamed since the base (the root's import lines apart): $nmod"
echo "lines removed from the root's imports: $(git -C "$WT" diff $BASE -- formal/ZK60Formal.lean | grep -c '^-[^-]')"
echo "Rust files changed since the base: $(git -C "$WT" diff --name-only $BASE -- '*.rs' | wc -l | tr -d ' ')"
ulimit -s 65520
echo "== the lane's checker: the approved block run on the R13 trace fixture =="
"$LAKE" -d "$WT/formal" env lean --run "$L/RunShapeCheck.lean" "$V/block_fixture_t32.tsv" "$V/block_trace_low_h24_t32.tsv" \
  "$V/block_trace_low_t32.tsv" "$R1/rust_fixture_trace.tsv" "$V/silu_-4_-13.bin" "$V/silu_-1_-11.bin" \
  "$WT/results/zk60_lean_l2d_20261106/rust_token_out.tsv" > "$OUT/runshapecheck.log" 2>&1
crs=$?
tail -n 1 "$OUT/runshapecheck.log"
echo "negative controls caught: $(grep -c 'negative control .*: caught' "$OUT/runshapecheck.log") of 14"
grs=1
grep -q '^RunShapeCheck: [0-9]* checks, 0 failed$' "$OUT/runshapecheck.log" \
  && [ "$(grep -c 'negative control .*: caught' "$OUT/runshapecheck.log")" -eq 14 ] && grs=0
echo "== the lane's export check: Shieldstral's calibrations and public data against the app's verifier export =="
python3 -I "$OUT/l40_shield_export.py" "$WT" > "$OUT/l40_shield_export.log" 2>&1
cex=$?
grep -E '^L40 SHIELD EXPORT' "$OUT/l40_shield_export.log"
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
g6=1
grep -q '^L6Check: 1206 checks, 0 failed$' "$OUT/l6check_regression.log" && g6=0
g5=1
grep -q '^L5Check: 5553 checks, 0 failed$' "$OUT/l5check_regression.log" && g5=0
g11=1
grep -q '^L11Check: 404 checks, 0 failed$' "$OUT/l11check_regression.log" && g11=0
g1=1
grep -q '^L1 TOTAL: 101956 checks, 0 failed$' "$OUT/l1check_regression.log" && g1=0
echo "regression verdicts: L6 $g6, L5 $g5, L11 $g11, L1 $g1 (0 = the committed count with 0 failed)"
echo "lane checker verdicts: RunShapeCheck $crs/$grs, export check $cex (0 = green)"
echo "total $(( $(date +%s) - start )) s"
[ $rc -eq 0 ] && [ "$nw" -eq 0 ] && [ "$nwp" -eq 0 ] && [ $arc -eq 0 ] && [ "$na" -eq "$ng" ] && [ "$nsa" -eq 0 ] \
  && [ "$nrb" -eq 0 ] && [ "$oth" -eq 0 ] && [ "$nel" -eq 0 ] && [ $scan -eq 0 ] && [ $imp -eq 0 ] && [ $unch -eq 0 ] \
  && [ "$nmod" -eq 0 ] && [ $crs -eq 0 ] && [ $grs -eq 0 ] && [ $cex -eq 0 ] \
  && [ $c6 -eq 0 ] && [ $c5 -eq 0 ] && [ $c11 -eq 0 ] && [ $c1 -eq 0 ] \
  && [ $g6 -eq 0 ] && [ $g5 -eq 0 ] && [ $g11 -eq 0 ] && [ $g1 -eq 0 ]
