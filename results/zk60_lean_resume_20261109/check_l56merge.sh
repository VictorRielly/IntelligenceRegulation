#!/bin/bash
# 2026-11-10, coordinator. Lane L56 (blockSchedXB, the L54-1 repair; RaDefAtB, the L56-7 repair; ShieldRunAt; the
# restated top theorems bnd_productionReadyL_epP_*) on the MERGED tree in the main checkout, as one guarded cpu job: the
# generic Lean check (check_lean_merge.sh: the full build, the axiom audits of every lane L9 on, the source scan of the
# lane's eight files, the regressions), then the lane's own steps: hashline's census tests and the lane's export test,
# the two generated files are their generators' output on the merged tree (both generators first, then both compared),
# and the lane's two code checks with their negative controls (l56_bnd_check.py on the committed real-receipt corpus;
# l56_src_check.py on the production sources). Every command reads /dev/null (L49-FZC-1).
set -u
R=/Users/victorrielly/IntelligenceRegulation
O=$R/results/zk60_lean_l56_20261110
L=$R/formal/ZK60Formal
M=$R/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
C="/opt/homebrew/bin/cargo test --release --offline --locked -j 2 --manifest-path $M --lib"
export LEAN_NUM_THREADS=4
/bin/bash $R/results/zk60_lean_resume_20261109/check_lean_merge.sh l56 RunBndSched.lean RunBndHal.lean \
  RunBndSem.lean RunBndArgs.lean RunBndDef.lean RunBndShield.lean RunBndChain.lean RunBndTop.lean < /dev/null
P=$O/l56merge.progress
X=$O/l56merge
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say "L56's own steps start"
for f in s25_tests hash_domain lean_l56_export_tests; do
  $C $f < /dev/null > ${X}_$f.log 2>&1; say "hashline $f rc=$?"
  grep -E "^test result" ${X}_$f.log >> $P
done
for f in RunBndChain RunBndTop; do cp $L/$f.lean $X.saved_$f.lean; done
for g in l56_mk_chain.py l56_mk_top.py; do
  python3 -I $O/$g $R < /dev/null > ${X}_gen_$g.log 2>&1; say "generator $g rc=$?"
done
for f in RunBndChain RunBndTop; do
  cmp -s $X.saved_$f.lean $L/$f.lean; say "$f.lean identical to its generator's output (cmp rc 0 = identical): rc=$?"
  cp $X.saved_$f.lean $L/$f.lean; rm -f $X.saved_$f.lean
done
python3 -I $O/l56_bnd_check.py $O/l56_corpus.txt --negative < /dev/null > ${X}_bndcheck.log 2>&1
say "l56_bnd_check.py (real receipt's boundary positions, with negative control) rc=$?"; tail -2 ${X}_bndcheck.log >> $P
python3 -I $O/l56_src_check.py $R/ops/zkp-mvp/gpu-metal/hashline/src/private_block --negative < /dev/null \
  > ${X}_srccheck.log 2>&1
say "l56_src_check.py (code facts in the source, with negative control) rc=$?"; tail -2 ${X}_srccheck.log >> $P
say "all done (L56)"
