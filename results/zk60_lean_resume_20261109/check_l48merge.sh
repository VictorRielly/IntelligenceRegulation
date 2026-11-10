#!/bin/bash
# 2026-11-10, coordinator. Lane L48 (the opening width as a parameter; the real stage and input-endpoint geometries
# checked against the code; the input commitment at its real geometry; the app's top theorem at the real widths) on
# the MERGED tree in the main checkout, as one guarded cpu job: the generic Lean check (check_lean_merge.sh: the full
# build, the axiom audits of every lane L9 on, the source scan of the lane's nine new files, its checker and the eight
# files it edited in place, the regressions), then the lane's own steps: the two generated files are their
# generators' output on the merged tree, and the agreement check against the code (RunOpenGeoCheck.lean on lane L29's
# corpus and the production sources) with its positive and negative controls (l48_negative.py).
set -u
R=/Users/victorrielly/IntelligenceRegulation
O=$R/results/zk60_lean_l48_20261110
L=$R/formal/ZK60Formal
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
export LEAN_NUM_THREADS=4
/bin/bash $R/results/zk60_lean_resume_20261109/check_lean_merge.sh l48 RunOpenGeo.lean RunOpenGeoTier.lean \
  RunOpenGeoStage.lean RunOpenGeoTop.lean RunOpenGeoBlock.lean BindingEP.lean ProtocolClassifyEP.lean \
  RunOpenGeoStageX.lean RunOpenGeoEP.lean RunOpenGeoCheck.lean RunTrKinds.lean RunKindsData.lean RunHalOpA.lean \
  RunHalOpB.lean RunHalBlk.lean RunStageRdHal.lean RunExtractStage.lean RunExtractParts.lean
P=$O/l48merge.progress
X=$O/l48merge
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say "L48's own steps start"
for g in Top:l48_mk_top.py EP:l48_mk_ep.py; do
  f=RunOpenGeo${g%%:*}.lean; s=${g##*:}
  cp $L/$f $X.saved.lean
  python3 -I $O/$s $R > ${X}_gen_${g%%:*}.log 2>&1; grc=$?
  cmp -s $X.saved.lean $L/$f; crc=$?
  cp $X.saved.lean $L/$f; rm -f $X.saved.lean
  say "generator $s rc=$grc; $f identical to its output (cmp rc 0 = identical): rc=$crc"
done
ulimit -s 65520
$LAKE -d $R/formal env lean --run $L/RunOpenGeoCheck.lean $R/results/zk60_lean_l29_20261107/corpus.txt \
  $R/ops/zkp-mvp/gpu-metal > ${X}_geocheck.log 2>&1
say "RunOpenGeoCheck rc=$?"; tail -1 ${X}_geocheck.log >> $P
L48_TREE=$R python3 -I $O/l48_negative.py > ${X}_negative.log 2>&1
say "l48_negative.py (positive and negative controls) rc=$?"; tail -1 ${X}_negative.log >> $P
say "all done (L48)"
