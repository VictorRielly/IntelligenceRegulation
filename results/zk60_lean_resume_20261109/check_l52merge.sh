#!/bin/bash
# 2026-11-10, coordinator. Lane L52 (repair B of finding L51-1; the input endpoint at the code's header; the app's top
# theorem eb_productionReadyL_epP_codeT) on the MERGED tree in the main checkout, as one guarded cpu job: the generic
# Lean check (check_lean_merge.sh: the full build, the axiom audits of every lane L9 on, the source scan of the lane's
# seven files, the regressions), then the lane's own steps: the four generated files are their generators' output on
# the merged tree (all four generators run first, then all four compared, as the lane's check does), and lane L51's
# agreement check of the code's header re-run (RunAbsCheck.lean on L51's corpus and the production sources).
set -u
R=/Users/victorrielly/IntelligenceRegulation
O=$R/results/zk60_lean_l52_20261110
L=$R/formal/ZK60Formal
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
export LEAN_NUM_THREADS=4
/bin/bash $R/results/zk60_lean_resume_20261109/check_lean_merge.sh l52 RunEpBOpen.lean RunEpBInc.lean \
  RunEpBChain.lean RunEpBTest.lean RunEpBTop.lean RunEpBTopT.lean RunEpBExt.lean
P=$O/l52merge.progress
X=$O/l52merge
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say "L52's own steps start"
G="RunEpBInc:l52_mk_inc.py RunEpBChain:l52_mk_chain.py RunEpBTop:l52_mk_top.py RunEpBTopT:l52_mk_topT.py"
for p in $G; do cp $L/${p%%:*}.lean $X.saved_${p%%:*}.lean; done
for p in $G; do python3 -I $O/${p##*:} $R > ${X}_gen_${p%%:*}.log 2>&1; say "generator ${p##*:} rc=$?"; done
for p in $G; do
  f=${p%%:*}
  cmp -s $X.saved_$f.lean $L/$f.lean; say "$f.lean identical to its generator's output (cmp rc 0 = identical): rc=$?"
  cp $X.saved_$f.lean $L/$f.lean; rm -f $X.saved_$f.lean
done
ulimit -s 65520
$LAKE -d $R/formal env lean --run $L/RunAbsCheck.lean $R/results/zk60_lean_l51_20261110/l51_corpus.txt \
  $R/ops/zkp-mvp/gpu-metal > ${X}_abscheck.log 2>&1
say "RunAbsCheck (L51's, re-run) rc=$?"; tail -1 ${X}_abscheck.log >> $P
say "all done (L52)"
