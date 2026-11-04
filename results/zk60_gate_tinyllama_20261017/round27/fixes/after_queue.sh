#!/bin/bash
# FR25 fixes, the coordinator's after-queue steps (README §7), detached: wait for the merged-gate queue on the main
# checkout to end (its logs/queue.done), then on the FIXED tool state in this worktree:
#  1. the full v25 suite (suite.sh, cpu class);
#  2. the re-gate of the two registered R13 rung bundles (regate.sh, cpu class), then check_records.py on them;
#  3. the fixed status rules applied read-only to the merged queue's records (exp_restatus.py), and check_records.py
#     on those records.
# Progress lines and each step's rc go to logs/after_queue.progress. A file logs/STOP ends it between steps.
set -u
T=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/fr25-fixes
F=$T/results/zk60_gate_tinyllama_20261017/round27/fixes
L=$F/logs
Q=$L/after_queue.progress
M=/Users/victorrielly/IntelligenceRegulation/results/zk60_d60_20261102/privacy_gate_merged
CHK=$M/check_records.py
mkdir -p $L
say() { echo "$(date -u +%FT%TZ) $*" >> $Q; }
stop() { [ -f $L/STOP ] && { say "STOP file found, ends"; exit 0; }; return 0; }
say start
until [ -f $M/logs/queue.done ]; do sleep 120; done
say "merged queue.done $(cat $M/logs/queue.done)"
stop
bash $F/suite.sh $T > $L/after_suite.out 2>&1; say "suite rc=$?"
stop
bash $F/regate.sh $T > $L/after_regate.out 2>&1; say "regate rc=$?"
python3 $CHK $F/records > $L/check_regate.out 2>&1; say "check_records regate rc=$?"
PY=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/gatevenv/bin/python3
$PY -B $F/exp_restatus.py $T/ops/zkp-mvp/gate-tinyllama/staging_v25/scripts $M/records/*.json > $L/restatus_merged.out 2>&1
say "restatus merged rc=$?"
python3 $CHK $M/records > $L/check_merged.out 2>&1; say "check_records merged rc=$?"
say "all done"
