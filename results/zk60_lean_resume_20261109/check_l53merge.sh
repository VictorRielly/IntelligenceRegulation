#!/bin/bash
# 2026-11-10, coordinator. Lane L53 (the two stages' parts: the lists chosen once to match the code's stage verifiers,
# the stage alive premises and the doom covers reduced to stage-level facts; RunStgTop / RunStgTopD) on the MERGED tree
# in the main checkout, as one guarded cpu job: the generic Lean check (check_lean_merge.sh: the full build, the axiom
# audits of every lane L9 on, the source scan of the lane's seven files and its checker, the regressions), then the
# lane's own steps: the two generated files are their generators' output on the merged tree, and the agreement check
# of the stage lists against the code (RunStgCheck.lean on lane L29's corpus and the stage verifier sources) with its
# positive and negative controls (l53_negative.py, tree from L53_TREE). Every lean --run reads /dev/null (L49-FZC-1).
set -u
R=/Users/victorrielly/IntelligenceRegulation
O=$R/results/zk60_lean_l53_20261110
L=$R/formal/ZK60Formal
TIO=$R/ops/zkp-mvp/gpu-metal/hashline/src/private_block/token_io
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
export LEAN_NUM_THREADS=4
/bin/bash $R/results/zk60_lean_resume_20261109/check_lean_merge.sh l53 RunStgList.lean RunStgAlive.lean \
  RunStgRun.lean RunStgHal.lean RunStgDoom.lean RunStgTop.lean RunStgTopD.lean RunStgCheck.lean < /dev/null
P=$O/l53merge.progress
X=$O/l53merge
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say "L53's own steps start"
for g in RunStgTop:l53_mk_top.py RunStgTopD:l53_mk_topd.py; do
  f=${g%%:*}; s=${g##*:}
  cp $L/$f.lean $X.saved.lean
  python3 -I $O/$s $R < /dev/null > ${X}_gen_$f.log 2>&1; grc=$?
  cmp -s $X.saved.lean $L/$f.lean; crc=$?
  cp $X.saved.lean $L/$f.lean; rm -f $X.saved.lean
  say "generator $s rc=$grc; $f.lean identical to its output (cmp rc 0 = identical): rc=$crc"
done
ulimit -s 65520
$LAKE -d $R/formal env lean --run $L/RunStgCheck.lean $R/results/zk60_lean_l29_20261107/corpus.txt \
  $TIO/stage_in_c.rs $TIO/stage_out_c.rs < /dev/null > ${X}_stgcheck.log 2>&1
say "RunStgCheck rc=$?"; tail -1 ${X}_stgcheck.log >> $P
L53_TREE=$R python3 -I $O/l53_negative.py < /dev/null > ${X}_negative.log 2>&1
say "l53_negative.py (positive and negative controls) rc=$?"; tail -1 ${X}_negative.log >> $P
say "all done (L53)"
