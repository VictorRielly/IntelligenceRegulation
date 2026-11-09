#!/bin/bash
# Lane A28 (diagnostics): one stream plan (runs.sh) with the one-thread memory-traffic probe running beside it
# (membw_probe.py -> <job>.membw.tsv): 20 s of the idle machine first, the plan, 20 s idle after. One guarded
# gpu-class job. Never for an A/B measurement (the probe is a load itself).
# usage: xprobe.sh <job tag> <plan file>
R=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a6d02411a78ede69c/results/zk60_a28_app_20261107
PY=/Users/victorrielly/zk60-artifacts/a28-tools/venv/bin/python
$PY $R/membw_probe.py $R/$1.membw.tsv --seconds 3000 &
W=$!
sleep 20
/bin/bash $R/runs.sh $1 $2
rc=$?
sleep 20
kill $W 2>/dev/null
rm -rf /Users/victorrielly/zk60-owner-private/a28-media-app-20261107/stream-* /Users/victorrielly/zk60-artifacts/a28-media-app-20261107/stream-*
exit $rc
