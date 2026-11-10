#!/bin/bash
# D63 lane L55 (2026-11-10; adapted from results/zk60_lean_l52_20261110/check_l52.sh): the full Lean build (the L55
# modules first, one at a time), the axiom audit of every theorem, definition and structure of the L55 files, the
# source scan (the L55 files, the checker, the generator and the negative control), the root imports, the list of
# existing files changed (none under formal/ but the root's import lines; Statements.lean unchanged; no Rust), the
# name-clash scan, the generated file against its generator, the boundary geometry checked against the code
# (RunCloseBGeoCheck.lean) with its negative control (l55_negative.py), lane L51's agreement check of the code's header
# re-run (RunAbsCheck.lean: the header vd_hW reads the verdict from), and the regressions (L6Check, L5Check, L11Check,
# the fixture L1 check; arguments as in L52's check), as ONE guarded job (run_guarded.py: class cpu, cap 36, need 24,
# LEAN_NUM_THREADS=4: finding L42-8). Exit code 0 only when every verdict is green.
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a33fed333d77ee386
MAIN=/Users/victorrielly/IntelligenceRegulation
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
OUT=$WT/results/zk60_lean_l55_20261110
O51=$WT/results/zk60_lean_l51_20261110
BASE=2e5cde97
O6=$WT/results/zk60_lean_l6_20261106
O5=$WT/results/zk60_lean_l5_20261106
O11=$WT/results/zk60_lean_l11_20261107
R1=$WT/results/zk60_lean_l1l2_20261106
V=$WT/ops/zkp-mvp/gpu-metal/hashline/src/private_block/r13_vectors
L=$WT/formal/ZK60Formal
export LEAN_NUM_THREADS=4
MODS=$(cat "$OUT/modules.txt")
FILES=""
for m in $MODS; do FILES="$FILES $L/$m.lean"; done
start=$(date +%s)
echo "== lake build of the L55 modules, one at a time =="
for m in $MODS; do
  "$LAKE" -d "$WT/formal" build ZK60Formal.$m < /dev/null > "$OUT/prebuild_$m.log" 2>&1
  echo "lake build ZK60Formal.$m rc $?"
done
echo "== lake build (full) =="
"$LAKE" -d "$WT/formal" build < /dev/null > "$OUT/full.log" 2>&1
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
echo "warnings in the modules' own builds: $nwp"
if [ $rc -ne 0 ]; then
  grep -E 'error' "$OUT/full.log" | head -n 20
  exit 1
fi
echo "== axiom audit (the L55 files) =="
gen=$(python3 -I "$OUT/gen_axioms.py" "$L" "$OUT/axioms_l55.lean" $MODS)
echo "$gen"
ng=${gen%% *}
"$LAKE" -d "$WT/formal" env lean "$OUT/axioms_l55.lean" < /dev/null > "$OUT/axioms.log" 2>&1
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
echo "== source scan of the L55 files, the checker and the scripts =="
scan=0
grep -n -E '\bsorry\b|\baxiom\b|native_decide|admit|maxRecDepth|maxHeartbeats|implemented_by|@\[extern|\bextern\b|bv_decide|ofReduceBool' \
  $FILES $L/RunCloseBGeoCheck.lean $OUT/l55_mk_top.py $OUT/l55_negative.py && scan=1 || echo "none"
echo "== the library root imports the L55 files =="
imp=0
for m in $MODS; do
  if grep -q "^import ZK60Formal.$m\$" "$WT/formal/ZK60Formal.lean"; then echo "imported: $m"; else echo "MISSING: $m"; imp=1; fi
done
grep -q "^import ZK60Formal.RunCloseBGeoCheck\$" "$WT/formal/ZK60Formal.lean" && { echo "the checker is imported (must not be)"; imp=1; }
echo "== existing files changed against perf's $BASE =="
unch=0
git -C "$WT" diff --quiet $BASE -- formal/ZK60Formal/Statements.lean && echo "Statements.lean unchanged" \
  || { echo "Statements.lean CHANGED"; unch=1; }
nmod=0
for f in $(git -C "$WT" diff --name-only --diff-filter=MDR $BASE -- formal); do
  case "$f" in
    formal/ZK60Formal.lean) ;;
    *) echo "NOT ALLOWED: $f"; nmod=$(( nmod + 1 )) ;;
  esac
done
echo "existing files under formal/ changed (the root's imports apart): $nmod"
nrm=$(git -C "$WT" diff $BASE -- formal/ZK60Formal.lean | grep -c '^-[^-]')
echo "lines removed from the root's imports: $nrm"
nrust=$(git -C "$WT" diff --name-only $BASE -- ops | wc -l | tr -d ' ')
echo "files changed under ops/: $nrust"
echo "== name clashes with the other worktrees' Lean files =="
python3 -I "$OUT/l55_nameclash.py" "$WT" "$MAIN" RunVerdict,RunCloseB "$BASE" > "$OUT/nameclash.log" 2>&1
ncl=$?
tail -n 3 "$OUT/nameclash.log"
echo "== the generated file is its generator's output =="
gok=0
cp "$L/RunVerdictTop.lean" "$OUT/l55_saved_RunVerdictTop.lean"
python3 -I "$OUT/l55_mk_top.py" "$WT" > /dev/null || gok=1
cmp -s "$OUT/l55_saved_RunVerdictTop.lean" "$L/RunVerdictTop.lean" && echo "RunVerdictTop.lean: identical" \
  || { echo "RunVerdictTop.lean: DIFFERS"; gok=1; }
cp "$OUT/l55_saved_RunVerdictTop.lean" "$L/RunVerdictTop.lean"
rm -f "$OUT/l55_saved_RunVerdictTop.lean"
ulimit -s 65520
echo "== the boundary geometry against the code (RunCloseBGeoCheck.lean) =="
"$LAKE" -d "$WT/formal" env lean --run "$L/RunCloseBGeoCheck.lean" "$WT/results/zk60_lean_l29_20261107/corpus.txt" \
  "$WT/results/zk60_lean_l49_20261110/pub_shield_short.txt" "$WT/ops/zkp-mvp/gpu-metal" < /dev/null > "$OUT/geocheck.log" 2>&1
cgc=$?
tail -n 6 "$OUT/geocheck.log"
echo "== its negative control (l55_negative.py) =="
python3 -I "$OUT/l55_negative.py" < /dev/null > "$OUT/negative.log" 2>&1
cneg=$?
tail -n 1 "$OUT/negative.log"
echo "== lane L51's agreement check of the code's header, re-run (RunAbsCheck.lean) =="
"$LAKE" -d "$WT/formal" env lean --run "$L/RunAbsCheck.lean" "$O51/l51_corpus.txt" "$WT/ops/zkp-mvp/gpu-metal" \
  < /dev/null > "$OUT/abscheck.log" 2>&1
cg=$?
tail -n 1 "$OUT/abscheck.log"
gg=1
grep -q '^RunAbsCheck: 29 checks, 0 failed$' "$OUT/abscheck.log" && gg=0
echo "== regression: L6Check on the committed L6 corpus =="
"$LAKE" -d "$WT/formal" env lean --run "$L/L6Check.lean" "$O6/corpus.txt" < /dev/null > "$OUT/l6check_regression.log" 2>&1
c6=$?
tail -n 1 "$OUT/l6check_regression.log"
echo "== regression: L5Check on the committed L5 corpus =="
"$LAKE" -d "$WT/formal" env lean --run "$L/L5Check.lean" "$O5/corpus.txt" < /dev/null > "$OUT/l5check_regression.log" 2>&1
c5=$?
tail -n 1 "$OUT/l5check_regression.log"
echo "== regression: L11Check on L11's committed W16R2 rung corpus =="
"$LAKE" -d "$WT/formal" env lean --run "$L/L11Check.lean" "$O11/corpus.txt" < /dev/null > "$OUT/l11check_regression.log" 2>&1
c11=$?
tail -n 1 "$OUT/l11check_regression.log"
echo "== regression: the fixture L1 check =="
"$LAKE" -d "$WT/formal" env lean --run "$L/L1Check.lean" "$V/block_fixture_t32.tsv" "$V/block_trace_low_h24_t32.tsv" \
  "$V/block_trace_low_t32.tsv" "$R1/rust_fixture_trace.tsv" "$V/r13_requant_vectors.tsv" < /dev/null \
  > "$OUT/l1check_regression.log" 2>&1
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
echo "verdicts: generated file $gok, geocheck $cgc, negative $cneg, abscheck $cg/$gg, L6 $g6, L5 $g5, L11 $g11, L1 $g1 (0 = as required)"
echo "total $(( $(date +%s) - start )) s"
[ $rc -eq 0 ] && [ "$nw" -eq 0 ] && [ "$nwp" -eq 0 ] && [ $arc -eq 0 ] && [ "$na" -eq "$ng" ] && [ "$nsa" -eq 0 ] \
  && [ "$nrb" -eq 0 ] && [ "$oth" -eq 0 ] && [ "$nel" -eq 0 ] && [ $scan -eq 0 ] && [ $imp -eq 0 ] && [ $unch -eq 0 ] \
  && [ "$nmod" -eq 0 ] && [ "$nrm" -eq 0 ] && [ "$nrust" -eq 0 ] && [ $ncl -eq 0 ] && [ $gok -eq 0 ] \
  && [ $cgc -eq 0 ] && [ $cneg -eq 0 ] && [ $cg -eq 0 ] && [ $gg -eq 0 ] && [ $c6 -eq 0 ] && [ $c5 -eq 0 ] \
  && [ $c11 -eq 0 ] && [ $c1 -eq 0 ] && [ $g6 -eq 0 ] && [ $g5 -eq 0 ] && [ $g11 -eq 0 ] && [ $g1 -eq 0 ]
