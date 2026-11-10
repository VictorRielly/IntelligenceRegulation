#!/bin/bash
# D63 lane L49 (2026-11-10; adapted from L47's check_l47.sh): the L49 modules built one at a time, the full Lean build,
# the axiom audit of every theorem, definition, abbreviation and structure of the L49 library files, the source scan,
# the root imports, the name-clash scan, the regressions (L6Check, L5Check, L11Check, the fixture L1 check; arguments as
# in check_l47.sh) and the lane's agreement checks against the code (BlockR13HostExportCheck on the committed short
# corpus, BlockR13LookSumCheck on lane L47's committed R13 corpus, each with its negative controls), as ONE guarded job
# (run_guarded.py, class cpu; a full build after a root change: cap 36 GiB, need 24, LEAN_NUM_THREADS=4, finding
# L42-8). Every command reads /dev/null (finding L49-FZC-1). Its exit code is 0 only when every verdict is green.
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a09954f00024476bf
MAIN=/Users/victorrielly/IntelligenceRegulation
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
OUT=$WT/results/zk60_lean_l49_20261110
O47=$WT/results/zk60_lean_l47_20261110
BASE=d707fcc2
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
EXTRA=$(cat "$OUT/extra_files.txt" 2>/dev/null)
start=$(date +%s)
echo "== lake build of the L49 modules, one at a time =="
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
echo "warnings in the L49 modules' own builds: $nwp"
if [ $rc -ne 0 ]; then
  grep -E 'error' "$OUT/full.log" | head -n 20
  exit 1
fi
echo "== axiom audit =="
gen=$(python3 -I "$OUT/gen_axioms.py" "$L" "$OUT/axioms_l49.lean" $MODS)
echo "$gen"
ng=${gen%% *}
"$LAKE" -d "$WT/formal" env lean "$OUT/axioms_l49.lean" < /dev/null > "$OUT/axioms.log" 2>&1
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
echo "== source scan of the L49 library files, checkers and test-only Rust =="
scan=0
grep -n -E '\bsorry\b|\baxiom\b|native_decide|admit|maxRecDepth|maxHeartbeats|implemented_by|@\[extern|\bextern\b|bv_decide|ofReduceBool' \
  $FILES $EXTRA && scan=1 || echo "none"
echo "== the library root imports the L49 files =="
imp=0
for m in $MODS; do
  if grep -q "^import ZK60Formal.$m\$" "$WT/formal/ZK60Formal.lean"; then echo "imported: $m"; else echo "MISSING: $m"; imp=1; fi
done
echo "== unchanged: Statements.lean and every existing Lean file, against the lane's base $BASE =="
unch=0
git -C "$WT" diff --quiet $BASE -- formal/ZK60Formal/Statements.lean && echo "Statements.lean unchanged" \
  || { echo "Statements.lean CHANGED"; unch=1; }
nmod=$(git -C "$WT" diff --name-only --diff-filter=MDR $BASE -- formal | grep -v -c '^formal/ZK60Formal.lean$')
echo "existing files under formal/ modified, deleted or renamed since the base (the root's import lines apart): $nmod"
echo "lines removed from the root's imports: $(git -C "$WT" diff $BASE -- formal/ZK60Formal.lean | grep -c '^-[^-]')"
echo "files changed under ops/ since the base (test-only Rust only):"
git -C "$WT" diff --name-only $BASE -- ops
nrust=$(git -C "$WT" diff --name-only $BASE -- ops | grep -v -c -E 'lean_l49_export_tests\.rs$|private_block/w16r2_tests\.rs$')
echo "files under ops/ other than the two test-only files: $nrust"
echo "== name clashes with the other worktrees' Lean files =="
python3 -I "$OUT/l49_nameclash.py" "$WT" "$MAIN" BlockR13Host,BlockR13Look,BlockR13Stmt > "$OUT/nameclash.log" 2>&1
ncl=$?
tail -n 1 "$OUT/nameclash.log"
ulimit -s 65520
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
echo "== the lane's agreement checks against the code =="
"$LAKE" -d "$WT/formal" env lean --run "$L/BlockR13HostExportCheck.lean" "$OUT/pub_r13_host_short.txt" neg < /dev/null \
  > "$OUT/check_export_host_short.log" 2>&1
ch=$?
grep -E '^checks:|^negative controls:' "$OUT/check_export_host_short.log"
gh=1
grep -q '^checks: 106 passed, 0 failed' "$OUT/check_export_host_short.log" \
  && grep -q '^negative controls: 25 of 25 caught$' "$OUT/check_export_host_short.log" && gh=0
"$LAKE" -d "$WT/formal" env lean --run "$L/BlockR13LookSumCheck.lean" "$O47/l47_r13_short.txt" neg < /dev/null \
  > "$OUT/check_sum_short.log" 2>&1
cs=$?
grep -E '^checks:|^negative controls:' "$OUT/check_sum_short.log"
gs=1
grep -q '^checks: 113 passed, 0 failed$' "$OUT/check_sum_short.log" \
  && grep -q '^negative controls: 13 of 13 caught$' "$OUT/check_sum_short.log" && gs=0
echo "agreement verdicts: host tables $gh, sum claim $gs (0 = as required)"
g6=1
grep -q '^L6Check: 1206 checks, 0 failed$' "$OUT/l6check_regression.log" && g6=0
g5=1
grep -q '^L5Check: 5553 checks, 0 failed$' "$OUT/l5check_regression.log" && g5=0
g11=1
grep -q '^L11Check: 404 checks, 0 failed$' "$OUT/l11check_regression.log" && g11=0
g1=1
grep -q '^L1 TOTAL: 101956 checks, 0 failed$' "$OUT/l1check_regression.log" && g1=0
echo "verdicts: L6 $g6, L5 $g5, L11 $g11, L1 $g1 (0 = as required)"
echo "total $(( $(date +%s) - start )) s"
[ $rc -eq 0 ] && [ "$nw" -eq 0 ] && [ "$nwp" -eq 0 ] && [ $arc -eq 0 ] && [ "$na" -eq "$ng" ] && [ "$nsa" -eq 0 ] \
  && [ "$nrb" -eq 0 ] && [ "$oth" -eq 0 ] && [ "$nel" -eq 0 ] && [ $scan -eq 0 ] && [ $imp -eq 0 ] && [ $unch -eq 0 ] \
  && [ "$nmod" -eq 0 ] && [ "$nrust" -eq 0 ] && [ $ncl -eq 0 ] \
  && [ $c6 -eq 0 ] && [ $c5 -eq 0 ] && [ $c11 -eq 0 ] && [ $c1 -eq 0 ] \
  && [ $g6 -eq 0 ] && [ $g5 -eq 0 ] && [ $g11 -eq 0 ] && [ $g1 -eq 0 ] \
  && [ $ch -eq 0 ] && [ $gh -eq 0 ] && [ $cs -eq 0 ] && [ $gs -eq 0 ]
