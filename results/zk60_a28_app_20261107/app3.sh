#!/bin/bash
# Lane A28, the app end to end (A24's phases): the real app in process (PM_PROVER=shieldstral-fast, the A28
# pin), public posts only: FOUR short posts one after another on one warm service (app1.sh's first phase four
# times, with four different public texts: one post's latency through the app, four samples). The
# driver is light and unguarded; the app launches its fast service as one guarded gpu-class job itself.
# The private run data and the published bundles are deleted at the end (their numbers are in app_<tag>/).
# usage: app3.sh <tag>
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a6d02411a78ede69c
R=$WT/results/zk60_a28_app_20261107
A24P=$WT/results/zk60_a24_app_20261107/posts
TAG=$1
if pgrep ds4-bench >/dev/null; then echo "POLLUTED: ds4-bench running at start" > $R/app_$TAG.quiet; else echo "quiet at start (no ds4-bench)" > $R/app_$TAG.quiet; fi
/Users/victorrielly/zk60-artifacts/a28-tools/venv/bin/python $R/app_driver.py --tag $TAG --warm \
  --binary /Users/victorrielly/zk60-artifacts/proven-media-fast/bin/zk60_classify.a28 \
  --phase one=$A24P/one_app.json --phase one_b=$R/posts/one_s1.json --phase one_c=$R/posts/one_s2.json --phase one_d=$A24P/one.json > $R/app_$TAG.out 2>&1
rc=$?
pgrep ds4-bench >/dev/null && echo "POLLUTED: ds4-bench running at end" >> $R/app_$TAG.quiet
echo "rc=$rc" >> $R/app_$TAG.quiet
# the service ends after the driver's STOP (its guard writes service.guard.done): wait for it, then delete
for i in $(seq 1 90); do [ -f /Users/victorrielly/zk60-owner-private/a28-app-$TAG/fast-service/service.guard.done ] && break; sleep 2; done
tail -1 $WT/results/zk60_resource_guard/history.jsonl > $R/app_$TAG.service_guard.json 2>/dev/null
rm -rf /Users/victorrielly/zk60-owner-private/a28-app-$TAG /Users/victorrielly/zk60-artifacts/a28-app-$TAG
echo "$rc" > $R/app_$TAG.done
