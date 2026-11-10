#!/bin/bash
# 2026-11-10, coordinator. Lane L55 (hW; every closing opening after part 0; finding L55-1 and vdChk; the top theorem
# cb_productionReadyL_epP_codeF) on the MERGED tree in the main checkout, as one guarded cpu job: the generic Lean
# check (check_lean_merge.sh: the full build, the axiom audits of every lane L9 on, the source scan of the lane's files
# and checker, the regressions), then the lane's own steps: the three generated files are their generators' output on
# the merged tree (all three generators first, then all three compared, as the lane's check does), the boundary
# geometry against the code (RunCloseBGeoCheck.lean) with its negative control (l55_negative.py, tree from L55_TREE),
# and lane L51's header check re-run. Every lean --run reads /dev/null (L49-FZC-1).
set -u
R=/Users/victorrielly/IntelligenceRegulation
O=$R/results/zk60_lean_l55_20261110
L=$R/formal/ZK60Formal
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
export LEAN_NUM_THREADS=4
/bin/bash $R/results/zk60_lean_resume_20261109/check_lean_merge.sh l55 RunVerdictW.lean RunVerdictTop.lean \
  RunCloseBGeo.lean RunCloseBPcs.lean RunCloseBRun.lean RunCloseBBlk.lean RunCloseBEnd.lean RunCloseBEnds.lean \
  RunCloseBInc.lean RunCloseBMid.lean RunCloseBTop.lean RunCloseBTopF.lean RunCloseBGeoCheck.lean < /dev/null
P=$O/l55merge.progress
X=$O/l55merge
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say "L55's own steps start"
for f in RunVerdictTop RunCloseBTop RunCloseBTopF; do cp $L/$f.lean $X.saved_$f.lean; done
for g in l55_mk_top.py l55_mk_topX.py l55_mk_topF.py; do
  python3 -I $O/$g $R < /dev/null > ${X}_gen_$g.log 2>&1; say "generator $g rc=$?"
done
for f in RunVerdictTop RunCloseBTop RunCloseBTopF; do
  cmp -s $X.saved_$f.lean $L/$f.lean; say "$f.lean identical to its generator's output (cmp rc 0 = identical): rc=$?"
  cp $X.saved_$f.lean $L/$f.lean; rm -f $X.saved_$f.lean
done
ulimit -s 65520
$LAKE -d $R/formal env lean --run $L/RunCloseBGeoCheck.lean $R/results/zk60_lean_l29_20261107/corpus.txt \
  $R/results/zk60_lean_l49_20261110/pub_shield_short.txt $R/ops/zkp-mvp/gpu-metal < /dev/null > ${X}_geocheck.log 2>&1
say "RunCloseBGeoCheck rc=$?"; tail -1 ${X}_geocheck.log >> $P
L55_TREE=$R python3 -I $O/l55_negative.py < /dev/null > ${X}_negative.log 2>&1
say "l55_negative.py (negative control) rc=$?"; tail -1 ${X}_negative.log >> $P
$LAKE -d $R/formal env lean --run $L/RunAbsCheck.lean $R/results/zk60_lean_l51_20261110/l51_corpus.txt \
  $R/ops/zkp-mvp/gpu-metal < /dev/null > ${X}_abscheck.log 2>&1
say "RunAbsCheck (L51's, re-run) rc=$?"; tail -1 ${X}_abscheck.log >> $P
say "all done (L55)"
