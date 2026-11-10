#!/bin/bash
# Lane A28: queue a guarded job only once an earlier job's .done marker exists (waits OUTSIDE the guard, so it
# holds no lock while it waits). usage: after.sh <done file to wait for> <run_guarded.py arguments...>
R=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a6d02411a78ede69c/results/zk60_a28_app_20261107
W=$1; shift
until [ -f "$W" ]; do sleep 30; done
python3 $R/run_guarded.py "$@"
