#!/bin/bash
# D63 lane L63 (2026-11-17): the check on the MERGED tree (perf eda8b4f7, which carries lane L62's RunBlkShieldInst, merged
# into the lane branch, plus the 30 `import ZK60Formal.RunStgShield...` lines in the root file). A copy of check_l63.sh with
# these changes only:
#   * BASE=eda8b4f7 (the perf commit that carries L62);
#   * a first step before the per-module builds: the full root build (`lake build ZK60Formal`), its warnings naming an
#     L63 file or RunBlkShieldInst.lean and its error lines counted (the per-module builds that follow are no-ops);
#   * the generator section also runs l63_mk_inahrun.py --check (13 generators, closing review finding L63-R2-1);
#   * the "unchanged against perf" section is replaced: Statements.lean unchanged; the root's diff against BASE is exactly
#     30 added `import ZK60Formal.RunStgShield...` lines and 0 removed; 0 existing files under formal/, ops/, src/ modified,
#     deleted or renamed since BASE, excluding the root;
#   * after the L63 axiom audit, the axiom audit of L62's top theorem (axioms_l62top.lean, which imports the whole root, so
#     it also shows the root loads without a name clash);
#   * the final verdict line names every condition.
# One guarded job (run_guarded.py, class cpu). Its exit code is 0 only when every verdict below is green.
export LEAN_NUM_THREADS=4
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a8b5788916259e1b2
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
OUT=$WT/results/zk60_lean_l63_20261116
O6=$WT/results/zk60_lean_l6_20261106
O5=$WT/results/zk60_lean_l5_20261106
O11=$WT/results/zk60_lean_l11_20261107
R1=$WT/results/zk60_lean_l1l2_20261106
V=$WT/ops/zkp-mvp/gpu-metal/hashline/src/private_block/r13_vectors
L=$WT/formal/ZK60Formal
BASE=eda8b4f7
MODS="RunStgShieldDef RunStgShieldRd RunStgShieldInst RunStgShieldTop RunStgShieldRbr RunStgShieldTrue RunStgShieldTrueRun RunStgShieldTopT RunStgShieldClaims RunStgShieldClaimsRun RunStgShieldTopC RunStgShieldInAH RunStgShieldInAHRun RunStgShieldTopI RunStgShieldC RunStgShieldDefC RunStgShieldCChain RunStgShieldCJoin RunStgShieldCWire RunStgShieldCTop RunStgShieldCTopT RunStgShieldCTopC RunStgShieldCTopI RunStgShieldIOTie RunStgShieldCTopK RunStgShieldCTopZ RunStgShieldOutTie RunStgShieldCTopF RunStgShieldInZero RunStgShieldCTopW"
FILES="$L/RunStgShieldDef.lean $L/RunStgShieldRd.lean $L/RunStgShieldInst.lean $L/RunStgShieldTop.lean $L/RunStgShieldRbr.lean $L/RunStgShieldTrue.lean $L/RunStgShieldTrueRun.lean $L/RunStgShieldTopT.lean $L/RunStgShieldClaims.lean $L/RunStgShieldClaimsRun.lean $L/RunStgShieldTopC.lean $L/RunStgShieldInAH.lean $L/RunStgShieldInAHRun.lean $L/RunStgShieldTopI.lean $L/RunStgShieldC.lean $L/RunStgShieldDefC.lean $L/RunStgShieldCChain.lean $L/RunStgShieldCJoin.lean $L/RunStgShieldCWire.lean $L/RunStgShieldCTop.lean $L/RunStgShieldCTopT.lean $L/RunStgShieldCTopC.lean $L/RunStgShieldCTopI.lean $L/RunStgShieldIOTie.lean $L/RunStgShieldCTopK.lean $L/RunStgShieldCTopZ.lean $L/RunStgShieldOutTie.lean $L/RunStgShieldCTopF.lean $L/RunStgShieldInZero.lean $L/RunStgShieldCTopW.lean"
start=$(date +%s)
echo "== full root build: lake build ZK60Formal (L62 and L63 modules together) =="
"$LAKE" -d "$WT/formal" build ZK60Formal < /dev/null > "$OUT/merge_rootbuild.log" 2>&1
rrc=$?
echo "root build rc $rrc"
rbw=$(grep -c -E "warning: .*(RunStgShield[A-Za-z0-9]*|RunBlkShieldInst)\.lean" "$OUT/merge_rootbuild.log")
rbe=$(grep -c "error" "$OUT/merge_rootbuild.log")
echo "root build: warnings naming a RunStgShield*.lean or RunBlkShieldInst.lean file: $rbw; error lines: $rbe"
if [ $rrc -ne 0 ]; then
  grep -E 'error' "$OUT/merge_rootbuild.log" | head -n 20
  exit 1
fi
echo "== lake build of the L63 modules, one at a time (no-ops after the root build) =="
brc=0
nwp=0
for m in $MODS; do
  "$LAKE" -d "$WT/formal" build ZK60Formal.$m < /dev/null > "$OUT/prebuild_$m.log" 2>&1
  r=$?
  echo "lake build ZK60Formal.$m rc $r"
  [ $r -ne 0 ] && brc=$r
  w=$(grep -c "warning: ZK60Formal/$m.lean" "$OUT/prebuild_$m.log")
  e=$(grep -c "error" "$OUT/prebuild_$m.log")
  echo "  warnings in $m.lean: $w; error lines: $e"
  nwp=$(( nwp + w ))
done
if [ $brc -ne 0 ]; then
  grep -E 'error' "$OUT"/prebuild_*.log | head -n 20
  exit 1
fi
echo "== axiom audit =="
gen=$(python3 -I "$OUT/gen_axioms.py" "$L" "$OUT/axioms_l63.lean")
echo "$gen"
ng=${gen%% *}
"$LAKE" -d "$WT/formal" env lean "$OUT/axioms_l63.lean" < /dev/null > "$OUT/axioms.log" 2>&1
arc=$?
echo "axioms rc $arc"
# Lean wraps a long report over several lines (continuations start with a space): join them, up to the closing bracket.
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
echo "the top theorem:"
grep 'sshC_productionReadyL_epP_claimsW\|sshC_productionReadyL_epP_claimsF\|sshC_productionReadyL_epP_claimsI\|ssh_productionReadyL_epP_def\|ssh_productionReadyL_epP_true\|ssh_productionReadyL_epP_claimsO\|ssh_productionReadyL_epP_claimsI' "$OUT/axioms_flat.log"
echo "== axiom audit of L62's top theorem on the whole root (import ZK60Formal) =="
"$LAKE" -d "$WT/formal" env lean "$OUT/axioms_l62top.lean" < /dev/null > "$OUT/axioms_l62top.log" 2>&1
a62rc=$?
echo "axioms_l62top rc $a62rc"
awk '/^ /{printf "%s", $0; next} {if (NR>1) printf "\n"; printf "%s", $0} END{printf "\n"}' "$OUT/axioms_l62top.log" \
  > "$OUT/axioms_l62top_flat.log"
cat "$OUT/axioms_l62top_flat.log"
n62=$(grep -c 'depends on axioms' "$OUT/axioms_l62top_flat.log")
n62l=$(grep -c -v 'depends on axioms' "$OUT/axioms_l62top_flat.log")
o62=$(grep 'depends on axioms' "$OUT/axioms_l62top_flat.log" \
  | grep -v -c -E "\[(propext|Classical.choice|Quot.sound)(, (propext|Classical.choice|Quot.sound))*\]$")
echo "L62 top: reports $n62 (expected 1); lines that are not a report: $n62l; other axioms: $o62"
echo "== source scan of the L63 files =="
scan=0
grep -n -E '\bsorry\b|\baxiom\b|native_decide|admit|maxRecDepth|maxHeartbeats|implemented_by|@\[extern|\bextern\b|bv_decide|ofReduceBool' $FILES \
  && scan=1 || echo "none"
echo "== the generators reproduce their files =="
python3 -I "$OUT/l63_mk_top.py" "$WT" --check
gch=$?
python3 -I "$OUT/l63_mk_topt.py" "$WT" --check
gcht=$?
[ $gcht -ne 0 ] && gch=$gcht
python3 -I "$OUT/l63_mk_topc.py" "$WT" --check
gchc=$?
[ $gchc -ne 0 ] && gch=$gchc
python3 -I "$OUT/l63_mk_topi.py" "$WT" --check
gchi=$?
[ $gchi -ne 0 ] && gch=$gchi
for g in l63_mk_c.py l63_mk_defc.py l63_mk_cchain.py l63_mk_topsc.py l63_mk_topk.py l63_mk_topz.py l63_mk_topo.py l63_mk_topw.py l63_mk_inahrun.py; do
  python3 -I "$OUT/$g" "$WT" --check
  r=$?
  echo "$g --check rc $r"
  [ $r -ne 0 ] && gch=$r
done
echo "== name clashes (RunStgShield*, every worktree) =="
python3 -I "$OUT/l63_nameclash.py" "$WT" /Users/victorrielly/IntelligenceRegulation RunStgShield
ncl=$?
echo "== against perf $BASE: Statements.lean, the root's diff, every existing file =="
unch=0
git -C "$WT" diff --quiet $BASE -- formal/ZK60Formal/Statements.lean \
  && echo "Statements.lean unchanged" || { echo "Statements.lean CHANGED"; unch=1; }
numstat=$(git -C "$WT" diff --numstat $BASE -- formal/ZK60Formal.lean)
echo "root numstat (added removed file): $numstat"
nadd=$(git -C "$WT" diff -U0 $BASE -- formal/ZK60Formal.lean | grep -c '^+[^+]')
nimp=$(git -C "$WT" diff -U0 $BASE -- formal/ZK60Formal.lean | grep -c '^+import ZK60Formal\.RunStgShield')
nrem=$(git -C "$WT" diff -U0 $BASE -- formal/ZK60Formal.lean | grep -c '^-[^-]')
echo "root diff: added lines $nadd, of which RunStgShield imports $nimp; removed lines $nrem"
rootok=1
[ "$nadd" -eq 30 ] && [ "$nimp" -eq 30 ] && [ "$nrem" -eq 0 ] && rootok=0
echo "root diff exactly 30 RunStgShield import lines added, 0 removed: $([ $rootok -eq 0 ] && echo yes || echo NO)"
nmod=$(git -C "$WT" diff --name-only --diff-filter=MDR $BASE -- formal ops src | grep -v '^formal/ZK60Formal.lean$' | wc -l | tr -d ' ')
echo "existing files under formal/, ops/, src/ modified, deleted or renamed since $BASE (excluding the root): $nmod"
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
g6=1
grep -q '^L6Check: 1206 checks, 0 failed$' "$OUT/l6check_regression.log" && g6=0
g5=1
grep -q '^L5Check: 5553 checks, 0 failed$' "$OUT/l5check_regression.log" && g5=0
g11=1
grep -q '^L11Check: 404 checks, 0 failed$' "$OUT/l11check_regression.log" && g11=0
g1=1
grep -q '^L1 TOTAL: 101956 checks, 0 failed$' "$OUT/l1check_regression.log" && g1=0
echo "regression verdicts: L6 $g6, L5 $g5, L11 $g11, L1 $g1 (0 = the committed count with 0 failed)"
echo "total $(( $(date +%s) - start )) s"
echo "VERDICT inputs: rootbuild rc $rrc, root warnings $rbw, root error lines $rbe, module builds rc $brc, module warnings $nwp, axioms rc $arc, audited $na of $ng, sorryAx $nsa, ofReduceBool $nrb, other axioms $oth, non-report lines $nel, L62 top rc $a62rc reports $n62 non-report $n62l other axioms $o62, source scan $scan, generators $gch, name clashes $ncl, Statements/unchanged $unch, root diff ok $rootok, modified existing files $nmod, regressions rc $c6/$c5/$c11/$c1 verdicts $g6/$g5/$g11/$g1"
[ $rrc -eq 0 ] && [ "$rbw" -eq 0 ] && [ "$rbe" -eq 0 ] \
  && [ $brc -eq 0 ] && [ "$nwp" -eq 0 ] && [ $arc -eq 0 ] && [ "$na" -eq "$ng" ] && [ "$nsa" -eq 0 ] \
  && [ "$nrb" -eq 0 ] && [ "$oth" -eq 0 ] && [ "$nel" -eq 0 ] \
  && [ $a62rc -eq 0 ] && [ "$n62" -eq 1 ] && [ "$n62l" -eq 0 ] && [ "$o62" -eq 0 ] \
  && [ $scan -eq 0 ] && [ $gch -eq 0 ] && [ $ncl -eq 0 ] \
  && [ $unch -eq 0 ] && [ $rootok -eq 0 ] && [ "$nmod" -eq 0 ] \
  && [ $c6 -eq 0 ] && [ $c5 -eq 0 ] && [ $c11 -eq 0 ] && [ $c1 -eq 0 ] \
  && [ $g6 -eq 0 ] && [ $g5 -eq 0 ] && [ $g11 -eq 0 ] && [ $g1 -eq 0 ]
