#!/bin/bash
# 2026-11-10, coordinator. Lane L39 (gap audit GA-1 repaired IN PLACE in RunTrStages.lean; the stage contracts at the
# real stage verifiers; the parse congruence; the covers restated; the top theorem restated in the old and in D76's
# approved form) on the MERGED tree in the main checkout, as one guarded cpu job: the generic Lean check
# (check_lean_merge.sh, with RunTrStages.lean in the source scan since it changed), then the two probes:
#  - the gap audit's gap_d_rtinc.lean (which PROVED the old contracts empty) must now FAIL to build;
#  - this lane's l39_ga1_rerun.lean (the audit's witness is outside the guard; the audit's conclusion is false at the
#    real contract) must build.
set -u
R=/Users/victorrielly/IntelligenceRegulation
O=$R/results/zk60_lean_l39_20261110
GAP=$R/results/zk60_gap_audit_premises_20261110
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
/bin/bash $R/results/zk60_lean_resume_20261109/check_lean_merge.sh l39 RunCoverAlive.lean RunCoverDefine.lean \
  RunCoverParse.lean RunCoverSome.lean RunCoverSomeL.lean RunCoverStage.lean RunTrStages.lean
P=$O/l39merge.progress
X=$O/l39merge
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say "L39's own steps start"
$LAKE -d $R/formal env lean $GAP/gap_d_rtinc.lean > ${X}_audit_probe.log 2>&1
say "the gap audit's gap_d_rtinc.lean against the repaired tree rc=$? (NONZERO required: the old emptiness proof must no longer build)"
grep -m3 -E "error" ${X}_audit_probe.log | cut -c1-240 >> $P
$LAKE -d $R/formal env lean $O/l39_ga1_rerun.lean > ${X}_l39_probe.log 2>&1
say "this lane's l39_ga1_rerun.lean rc=$? (0 required)"
grep -E "depends on axioms" ${X}_l39_probe.log | cut -c1-200 >> $P
say "all done (L39)"
