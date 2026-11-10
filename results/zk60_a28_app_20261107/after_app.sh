#!/bin/bash
# Lane A28: start an app run (app1.sh; the app launches its own guarded service job) once an earlier job's .done
# marker exists and 90 more seconds have passed (another lane's waiting job goes first).
# usage: after_app.sh <done file to wait for> <app tag>
R=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a6d02411a78ede69c/results/zk60_a28_app_20261107
W=$1
until [ -f "$W" ]; do sleep 20; done
sleep 90
/bin/bash $R/app1.sh $2
