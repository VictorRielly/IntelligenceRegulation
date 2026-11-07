#!/bin/bash
# Lane A27 (from A26): the native resident servers on a list of public posts (inside a guarded gpu-class job).
# usage: stream.sh <tag> <posts.json> [driver flags...]   (quiet-box record in stream_<tag>.quiet)
R=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a6ef8e7c158543247/results/zk60_a27_app_20261107
TAG=$1; POSTS=$2; shift 2
if pgrep ds4-bench >/dev/null; then echo "POLLUTED: ds4-bench running at start" > $R/stream_$TAG.quiet; else echo "quiet at start (no ds4-bench)" > $R/stream_$TAG.quiet; fi
( while true; do pgrep ds4-bench >/dev/null && echo "POLLUTED: ds4-bench seen at $(date -u +%H:%M:%S)" >> $R/stream_$TAG.quiet; sleep 30; done ) &
W=$!
/private/tmp/zk60-astra-app-refresh-20261104-venv/bin/python $R/stream_driver.py --tag $TAG --posts $POSTS "$@"
rc=$?
kill $W 2>/dev/null
pgrep ds4-bench >/dev/null && echo "POLLUTED: ds4-bench running at end" >> $R/stream_$TAG.quiet
echo "rc=$rc" >> $R/stream_$TAG.quiet
exit $rc
