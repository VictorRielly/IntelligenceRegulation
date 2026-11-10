#!/bin/bash
# Lane A28 (resumed): after.sh with a pause. Queue a guarded job only once an earlier job's .done marker exists
# and 90 more seconds have passed with this lane out of the guard's queue, so a waiting job of another lane
# (the guard's waiters poll once a minute) gets the heavy lock first. Waits OUTSIDE the guard.
# usage: after2.sh <done file to wait for> <run_guarded.py arguments...>
R=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a6d02411a78ede69c/results/zk60_a28_app_20261107
W=$1; shift
until [ -f "$W" ]; do sleep 20; done
sleep 90
python3 $R/run_guarded.py "$@"
