#!/bin/bash
# FR25-17 closing run (2026-11-02): one guarded run of fr25_17_nl1_all23.py.
# Usage: run.sh <class> <need-gib> <cap-gib> <tag> <bundle dir> [extra args, e.g. --reference-record <json>]
#   development (rung bundle, beside the merged queue): run.sh light 3 3 dev-rung <rung bundle> --modes run
#   the closing runs: chain.sh (cpu class, need 6)
# Records go to records/ (dev runs to dev/), logs to logs/ (the guard's log, .done and .guard.json).
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a0f46a16788e085dc
G="python3 /Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
D=$W/results/zk60_d60_20261102/privacy_gate_fr25_17
PY=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/gatevenv/bin/python3
CLS=$1; NEED=$2; CAP=$3; TAG=$4; BUNDLE=$5; shift 5
case $TAG in dev-*) E=$D/dev ;; *) E=$D/records ;; esac
L=$D/logs
mkdir -p $E $L
rm -f $L/$TAG.log $L/$TAG.guard.done $L/$TAG.guard.json
$G --class $CLS --need-gib $NEED --cap-gib $CAP --label fr25-17-$TAG --wait-secs 43200 --max-secs 7200 \
  --log $L/$TAG.log --done $L/$TAG.guard.done --result-json $L/$TAG.guard.json -- \
  $PY -B $D/fr25_17_nl1_all23.py --bundle $BUNDLE --evidence $E --name $TAG "$@"
rc=$?
grep -v "^\[zk60-guard" $L/$TAG.log | tail -60
grep "zk60-guard.*END" $L/$TAG.log
exit $rc
