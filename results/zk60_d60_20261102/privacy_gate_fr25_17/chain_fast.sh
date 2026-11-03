#!/bin/bash
# FR25-17 closing runs, second launcher: chain.sh with the guard's admission poll at 0.5 s (ZK60_GUARD_POLL_SECS, this
# guard process only; default 5 s).  The merged queue relaunches its next bundle run within a second of the last one
# ending, so a 5 s poll almost never gets the lock between its runs.  The leaf is the same three.sh, which exits at
# once if the other launcher already completed the pass (logs/three.complete).  Launch detached:
#   python3 detach.py logs/chain_fast bash chain_fast.sh
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a0f46a16788e085dc
D=$W/results/zk60_d60_20261102/privacy_gate_fr25_17
L=$D/logs
mkdir -p $L
env ZK60_GUARD_POLL_SECS=0.5 python3 /Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py run \
  --class cpu --need-gib 6 --cap-gib 10 --label fr25-17-closing-fast --wait-secs 43200 --max-secs 7200 \
  --log $L/closing_fast.log --done $L/closing_fast.guard.done --result-json $L/closing_fast.guard.json -- \
  bash $D/three.sh
rc=$?
grep "zk60-guard.*END" $L/closing_fast.log
exit $rc
