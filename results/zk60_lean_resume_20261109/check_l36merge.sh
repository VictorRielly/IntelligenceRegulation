#!/bin/bash
# 2026-11-10, coordinator. Lane L36 (the block's per-outcome algebra; finding L36-1 repaired at the lookup bound 2^26)
# on the MERGED tree in the main checkout, as one guarded cpu job: the generic Lean check (check_lean_merge.sh), then
# the lane's own checker BlockAlgCheck on L17's committed shape corpus and its negative control (written outside the
# repository; exactly 7 failures required).
set -u
R=/Users/victorrielly/IntelligenceRegulation
O=$R/results/zk60_lean_l36_20261109
O17=$R/results/zk60_lean_l17_20261107
L=$R/formal/ZK60Formal
ART=/Users/victorrielly/zk60-artifacts/lean-merge-fixtures/l36merge
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
/bin/bash $R/results/zk60_lean_resume_20261109/check_lean_merge.sh l36 BlockAlgUnmask.lean BlockAlgKinds.lean \
  BlockAlgInst.lean BlockAlgRels.lean BlockAlgShapes.lean BlockAlgFinal.lean BlockAlgR13.lean BlockAlgLk26.lean \
  BlockAlgLkR13.lean BlockAlgLkW16.lean BlockAlgLkFinal.lean BlockAlgSat.lean BlockAlgCheck.lean
P=$O/l36merge.progress
X=$O/l36merge
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say "L36's own steps start"
ulimit -s 65520
$LAKE -d $R/formal env lean --run $L/BlockAlgCheck.lean $O17/shape_corpus.txt > ${X}_blockalgcheck.log 2>&1
say "BlockAlgCheck on L17's committed shape corpus rc=$?"
grep -E "^FAIL|^BlockAlgCheck" ${X}_blockalgcheck.log >> $P
rm -rf $ART; mkdir -p $ART
python3 -I $O/l36_mutate.py $O17/shape_corpus.txt $ART
$LAKE -d $R/formal env lean --run $L/BlockAlgCheck.lean $ART/l36_mut_shape.txt > ${X}_negative.log 2>&1
say "negative control (nonzero rc and 7 failed required) rc=$?"
grep -E "^BlockAlgCheck" ${X}_negative.log >> $P
say "all done (L36)"
