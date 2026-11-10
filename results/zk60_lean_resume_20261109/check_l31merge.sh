#!/bin/bash
# 2026-11-09, coordinator. Lane L31 (the block instance: the profile objects, the claims' reader, the mask half of
# the slot polynomials, the block chain on the repaired premise SlotEvalN) on the MERGED tree in the main checkout,
# as one guarded cpu job: the generic Lean check (check_lean_merge.sh), then the lane's own agreement check
# BlockInstCheck on the committed corpora (L9's, L17's block and shape corpora) and its negative control (eight single
# changes, written outside the repository; exactly 8 failures required).
set -u
R=/Users/victorrielly/IntelligenceRegulation
O=$R/results/zk60_lean_l31_20261109
O9=$R/results/zk60_lean_l9_20261107
O17=$R/results/zk60_lean_l17_20261107
L=$R/formal/ZK60Formal
ART=/Users/victorrielly/zk60-artifacts/lean-merge-fixtures/l31merge
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
/bin/bash $R/results/zk60_lean_resume_20261109/check_lean_merge.sh l31 BlockInstRead.lean BlockInstProf.lean \
  BlockInstRung.lean BlockInstShield.lean SlotPolyInstMask.lean SlotPolyInstEval.lean BlockInstChainN.lean \
  BlockInstFinal.lean BlockInstCheck.lean
P=$O/l31merge.progress
X=$O/l31merge
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say "L31's own steps start"
ulimit -s 65520
$LAKE -d $R/formal env lean --run $L/BlockInstCheck.lean $O9/corpus.txt $O17/block_corpus.txt $O17/shape_corpus.txt \
  > ${X}_blockinstcheck.log 2>&1; say "BlockInstCheck on the committed corpora rc=$?"
grep -E "^FAILED|^BlockInstCheck" ${X}_blockinstcheck.log >> $P
rm -rf $ART; mkdir -p $ART
python3 -I $O/l31_mutate.py $O9/corpus.txt $O17/block_corpus.txt $O17/shape_corpus.txt $ART
$LAKE -d $R/formal env lean --run $L/BlockInstCheck.lean $ART/l31_mut_corpus16.txt $ART/l31_mut_corpus13.txt \
  $ART/l31_mut_shape.txt > ${X}_negative.log 2>&1; say "negative control (eight single changes; nonzero rc and 8 failed required) rc=$?"
grep -E "^BlockInstCheck" ${X}_negative.log >> $P
say "all done (L31)"
