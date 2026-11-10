#!/bin/bash
# 2026-11-10, coordinator. Lane L57 (the stages' algebra under view lists; finding L57-1; the IN-C head count at the
# app's profile; stgAlg_productionReadyL_epP_exec_view / _exec_real) on the MERGED tree in the main checkout, as one
# guarded cpu job: the generic Lean check (check_lean_merge.sh: the full build, the axiom audits of every lane L9 on,
# the source scan of the lane's seven files, the regressions), then the lane's own steps: the two generated files are
# their generators' output on the merged tree (each generated, compared and restored in turn, as the lane's check
# does), and the IN-C count check against the code with its negative control (l57_count_check.py). Every command
# reads /dev/null (L49-FZC-1).
set -u
R=/Users/victorrielly/IntelligenceRegulation
O=$R/results/zk60_lean_l57_20261110
L=$R/formal/ZK60Formal
export LEAN_NUM_THREADS=4
/bin/bash $R/results/zk60_lean_resume_20261109/check_lean_merge.sh l57 RunStgAlgHost.lean RunStgAlgList.lean \
  RunStgAlgRun.lean RunStgAlgPoly.lean RunStgAlgCount.lean RunStgAlgTop.lean RunStgAlgTopR.lean < /dev/null
P=$O/l57merge.progress
X=$O/l57merge
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say "L57's own steps start"
for g in RunStgAlgTop:l57_mk_top.py RunStgAlgTopR:l57_mk_topr.py; do
  f=${g%%:*}; s=${g##*:}
  cp $L/$f.lean $X.saved.lean
  python3 -I $O/$s $R < /dev/null > ${X}_gen_$f.log 2>&1; grc=$?
  cmp -s $X.saved.lean $L/$f.lean; crc=$?
  cp $X.saved.lean $L/$f.lean; rm -f $X.saved.lean
  say "generator $s rc=$grc; $f.lean identical to its output (cmp rc 0 = identical): rc=$crc"
done
python3 -I $O/l57_count_check.py $R < /dev/null > ${X}_countcheck.log 2>&1
say "l57_count_check.py (IN-C head at the app's profile, with negative control) rc=$?"
grep -E '^L57 count check' ${X}_countcheck.log >> $P
say "all done (L57)"
