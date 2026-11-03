#!/bin/bash
# FR25-17 closing runs: ONE guarded cpu job (need 6 GiB) whose leaf is three.sh, so the heavy lock is taken once
# and the merged-gate queue's next bundle run waits about one closing pass.  Launch detached:
#   python3 detach.py logs/chain bash chain.sh
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a0f46a16788e085dc
G="python3 /Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
D=$W/results/zk60_d60_20261102/privacy_gate_fr25_17
L=$D/logs
mkdir -p $L
rm -f $L/closing.log $L/closing.guard.done $L/closing.guard.json $L/three.progress
$G --class cpu --need-gib 6 --cap-gib 10 --label fr25-17-closing --wait-secs 43200 --max-secs 7200 \
  --log $L/closing.log --done $L/closing.guard.done --result-json $L/closing.guard.json -- \
  bash $D/three.sh
rc=$?
grep "zk60-guard.*END" $L/closing.log
exit $rc
