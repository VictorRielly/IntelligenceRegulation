#!/bin/bash
# FR25-17 closing runs (2026-11-02): fork 1 of the three bundles the review names, one python process each, in
# sequence.  Run ONLY as the leaf of one guarded cpu job (chain.sh); it guards nothing itself.  Each process writes
# its own record (records/fr25_17-<tag>.json: its own wall time and peak RSS); this script logs each rc.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a0f46a16788e085dc
D=$W/results/zk60_d60_20261102/privacy_gate_fr25_17
PY=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/gatevenv/bin/python3
B=/Users/victorrielly/zk60-artifacts/d60_20261102/pg_bundles_r26
N=/Users/victorrielly/zk60-artifacts/d60_20261102/pg_bundles_bases
M=/Users/victorrielly/IntelligenceRegulation/results/zk60_d60_20261102/privacy_gate_merged/records
E=$D/records
P=$D/logs/three.progress
C=$D/logs/three.complete
mkdir -p $E
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
# two launchers may wait for the lock (chain.sh, chain_fast.sh); whichever starts second finds this marker and stops
if [ -f $C ]; then say "three.complete exists ($(cat $C)): nothing to do (job ${ZK60_GUARD_RUN_ID:-?})"; exit 0; fi
say "job ${ZK60_GUARD_RUN_ID:-?} starts the closing pass"
one() {  # tag, bundle, [reference record]
  local tag=$1 bundle=$2 ref=${3:-}
  say "start $tag"
  if [ -n "$ref" ] && [ -f "$ref" ]; then
    $PY -B $D/fr25_17_nl1_all23.py --bundle $bundle --evidence $E --name $tag --fork 1 --reference-record $ref
  else
    $PY -B $D/fr25_17_nl1_all23.py --bundle $bundle --evidence $E --name $tag --fork 1
  fi
  say "$tag rc=$?"
}
one r13-8b-t128-s0 $B/d55-r13_8b_t128_h24-s0 $M/d55-mg-r13-8b-s0.json
one shield-t256-s0 $N/d55-r13_shield_t256_h24-s0 $M/d55-mg-shield-t256-s0.json
one tiny-t128-s0 $N/d55-r13_tiny_t128_low-s0 $M/d55-mg-tiny-t128-s0.json
say "all done"
echo "done by job ${ZK60_GUARD_RUN_ID:-?} at $(date -u +%FT%TZ)" > $C
