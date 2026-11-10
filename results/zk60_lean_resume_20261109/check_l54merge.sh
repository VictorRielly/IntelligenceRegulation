#!/bin/bash
# 2026-11-10, coordinator. Lane L54 (the run-level hsem; hsl_blk from it; the 26 layers' slot shape; the top theorem
# wr_productionReadyL_epP_codeT) on the MERGED tree in the main checkout, as one guarded cpu job: the generic Lean check
# (check_lean_merge.sh: the full build, the axiom audits of every lane L9 on, the source scan of the lane's three
# files, the regressions), then the lane's own step: RunWireTop.lean is its generator's output on the merged tree.
# Every lean --run reads /dev/null (L49-FZC-1).
set -u
R=/Users/victorrielly/IntelligenceRegulation
O=$R/results/zk60_lean_l54_20261110
L=$R/formal/ZK60Formal
export LEAN_NUM_THREADS=4
/bin/bash $R/results/zk60_lean_resume_20261109/check_lean_merge.sh l54 RunWireSem.lean RunWireTerm.lean \
  RunWireTop.lean < /dev/null
P=$O/l54merge.progress
X=$O/l54merge
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say "L54's own steps start"
cp $L/RunWireTop.lean $X.saved.lean
python3 -I $O/l54_mk_top.py $R < /dev/null > ${X}_gen_top.log 2>&1; grc=$?
cmp -s $X.saved.lean $L/RunWireTop.lean; crc=$?
cp $X.saved.lean $L/RunWireTop.lean; rm -f $X.saved.lean
say "generator l54_mk_top.py rc=$grc; RunWireTop.lean identical to its output (cmp rc 0 = identical): rc=$crc"
say "all done (L54)"
