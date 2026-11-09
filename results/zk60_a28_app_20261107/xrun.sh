#!/bin/bash
# Lane A28 (resumed 2026-11-09): one guarded gpu-class job = one stream plan (runs.sh), then this lane's run data
# deleted (the posts' activations and owner files under ~/zk60-owner-private/a28-media-app-20261107/stream-*, what is
# left of the receipts under ~/zk60-artifacts/a28-media-app-20261107/stream-*): their numbers are in stream_<tag>/.
# usage: xrun.sh <job tag> <plan file>
R=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a6d02411a78ede69c/results/zk60_a28_app_20261107
/bin/bash $R/runs.sh $1 $2
rc=$?
rm -rf /Users/victorrielly/zk60-owner-private/a28-media-app-20261107/stream-* /Users/victorrielly/zk60-artifacts/a28-media-app-20261107/stream-*
exit $rc
