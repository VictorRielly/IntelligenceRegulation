#!/bin/bash
# 2026-11-10, coordinator. Lane L51 (the classify run header modelled and checked; finding L51-1; the general
# extraction colXM; the top theorem at repair A's header) on the MERGED tree in the main checkout, as one guarded cpu
# job: the generic Lean check (check_lean_merge.sh: the full build, the axiom audits of every lane L9 on, the source
# scan of the lane's files, the regressions), then the lane's own steps: hashline's census tests and the lane's
# test-only export test, RunAbsTop.lean is its generator's output on the merged tree, and the agreement check against
# the code (RunAbsCheck.lean on the lane's committed corpus and the production sources) with its positive and negative
# controls (l51_negative.py).
# Lane L50 (the alive conditions; RunAlive*.lean) was merged right after L51, so this ONE check covers both: L50's six
# files are in the source scan, and its generated RunAliveTop.lean is checked against l50_mk_top.py; the progress file
# for both is results/zk60_lean_l51_20261110/l51merge.progress.
set -u
R=/Users/victorrielly/IntelligenceRegulation
O=$R/results/zk60_lean_l51_20261110
L=$R/formal/ZK60Formal
M=$R/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
C="/opt/homebrew/bin/cargo test --release --offline --locked -j 2 --manifest-path $M --lib"
export LEAN_NUM_THREADS=4
/bin/bash $R/results/zk60_lean_resume_20261109/check_lean_merge.sh l51 RunAbsHdr.lean RunAbsX.lean RunAbsTop.lean \
  RunEndptWin.lean RunAbsCheck.lean RunAliveRed.lean RunAliveSl.lean RunAliveDef.lean RunAliveRun.lean \
  RunAliveHal.lean RunAliveTop.lean
P=$O/l51merge.progress
X=$O/l51merge
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say "L51's own steps start"
for f in s25_tests hash_domain lean_l51_export_tests; do
  $C $f > ${X}_$f.log 2>&1; say "hashline $f rc=$?"
  grep -E "^test result" ${X}_$f.log >> $P
done
cp $L/RunAbsTop.lean $X.saved.lean
python3 -I $O/l51_mk_top.py $R > ${X}_gen_top.log 2>&1; grc=$?
cmp -s $X.saved.lean $L/RunAbsTop.lean; crc=$?
cp $X.saved.lean $L/RunAbsTop.lean; rm -f $X.saved.lean
say "generator l51_mk_top.py rc=$grc; RunAbsTop.lean identical to its output (cmp rc 0 = identical): rc=$crc"
cp $L/RunAliveTop.lean $X.saved.lean
python3 -I $R/results/zk60_lean_l50_20261110/l50_mk_top.py $R > ${X}_gen_l50top.log 2>&1; grc=$?
cmp -s $X.saved.lean $L/RunAliveTop.lean; crc=$?
cp $X.saved.lean $L/RunAliveTop.lean; rm -f $X.saved.lean
say "generator l50_mk_top.py (lane L50) rc=$grc; RunAliveTop.lean identical to its output (cmp rc 0 = identical): rc=$crc"
ulimit -s 65520
$LAKE -d $R/formal env lean --run $L/RunAbsCheck.lean $O/l51_corpus.txt $R/ops/zkp-mvp/gpu-metal > ${X}_abscheck.log 2>&1
say "RunAbsCheck rc=$?"; tail -1 ${X}_abscheck.log >> $P
L51_TREE=$R python3 -I $O/l51_negative.py > ${X}_negative.log 2>&1
say "l51_negative.py (positive and negative controls) rc=$?"; tail -1 ${X}_negative.log >> $P
say "all done (L51)"
