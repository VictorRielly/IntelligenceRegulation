#!/bin/bash
# Lane A28 (from A27): the proven-media app suite (simulated servers; the coordinator's command), from this worktree.
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a6d02411a78ede69c
R=$WT/results/zk60_a28_app_20261107
TAG=${1:-app_tests}
/usr/bin/env PM_TINYLLAMA_TOKENIZER=/Users/victorrielly/IntelligenceRegulation/results/zk60_astra_20261026/app_decision_refresh_20261104/tokenizers/tokenizer.model \
  PYTHONPATH=$WT/apps/proven-media PYTHONDONTWRITEBYTECODE=1 \
  /private/tmp/zk60-astra-app-refresh-20261104-venv/bin/python -m unittest discover -s $WT/apps/proven-media/tests > $R/$TAG.log 2>&1
rc=$?
echo "rc=$rc" >> $R/$TAG.log
exit $rc
