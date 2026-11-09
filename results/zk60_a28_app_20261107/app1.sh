#!/bin/bash
# Lane A27, the app end to end (A24's phases): the real app in process (PM_PROVER=shieldstral-fast, the A27
# pin), public posts only: one short post, one long post (3 chunks per category), an 8-post stream. The
# driver is light and unguarded; the app launches its fast service as one guarded gpu-class job itself.
# usage: app1.sh <tag>
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a6d02411a78ede69c
R=$WT/results/zk60_a28_app_20261107
A24P=$WT/results/zk60_a24_app_20261107/posts
TAG=$1
if pgrep ds4-bench >/dev/null; then echo "POLLUTED: ds4-bench running at start" > $R/app_$TAG.quiet; else echo "quiet at start (no ds4-bench)" > $R/app_$TAG.quiet; fi
/Users/victorrielly/zk60-artifacts/a28-tools/venv/bin/python $R/app_driver.py --tag $TAG --warm \
  --binary /Users/victorrielly/zk60-artifacts/proven-media-fast/bin/zk60_classify.a27 \
  --phase one=$A24P/one_app.json --phase long=$A24P/long.json --phase stream8=$A24P/stream8.json > $R/app_$TAG.out 2>&1
rc=$?
pgrep ds4-bench >/dev/null && echo "POLLUTED: ds4-bench running at end" >> $R/app_$TAG.quiet
echo "rc=$rc" >> $R/app_$TAG.quiet
