#!/bin/bash
# 2026-11-10, coordinator. Lane L35 (the block's define as a Lean slot program and the tables part of the slot
# polynomials) on the MERGED tree in the main checkout, as one guarded cpu job: the generic Lean check
# (check_lean_merge.sh), then the lane's agreement check BlockDefineCheck on L11's committed W16R2 rung corpus and
# L9's corpus (its SITES), and its negative control (ten single changes, written outside the repository; exactly 10
# failures required).
set -u
R=/Users/victorrielly/IntelligenceRegulation
O=$R/results/zk60_lean_l35_20261109
O9=$R/results/zk60_lean_l9_20261107
O11=$R/results/zk60_lean_l11_20261107
L=$R/formal/ZK60Formal
ART=/Users/victorrielly/zk60-artifacts/lean-merge-fixtures/l35merge
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
/bin/bash $R/results/zk60_lean_resume_20261109/check_lean_merge.sh l35 BlockDefineAff.lean BlockDefineAlg.lean \
  BlockDefineClaim.lean BlockDefineFinal.lean BlockDefinePoly.lean BlockDefineSym.lean BlockDefineTab.lean \
  BlockDefineUnfold.lean BlockDefineW16.lean BlockDefineW16Final.lean BlockDefineW16Rung.lean BlockDefineCheck.lean
P=$O/l35merge.progress
X=$O/l35merge
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say "L35's own steps start"
ulimit -s 65520
$LAKE -d $R/formal env lean --run $L/BlockDefineCheck.lean $O11/corpus.txt $O9/corpus.txt > ${X}_blockdefinecheck.log 2>&1
say "BlockDefineCheck on L11's and L9's committed corpora rc=$?"
grep -E "^FAILED|^BlockDefineCheck" ${X}_blockdefinecheck.log >> $P
rm -rf $ART; mkdir -p $ART
python3 -I $O/l35_mutate.py $O11/corpus.txt $O9/corpus.txt $ART
$LAKE -d $R/formal env lean --run $L/BlockDefineCheck.lean $ART/l35_mut_corpus11.txt $ART/l35_mut_corpus9.txt \
  > ${X}_negative.log 2>&1; say "negative control (ten single changes; nonzero rc and 10 failed required) rc=$?"
grep -E "^BlockDefineCheck" ${X}_negative.log >> $P
say "all done (L35)"
