#!/bin/bash
# Lane A28 (from A27, A26): the native resident servers on a list of public posts (inside a guarded gpu-class job).
# usage: stream.sh <tag> <posts.json> [driver flags...]   (quiet-box record in stream_<tag>.quiet)
R=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a6d02411a78ede69c/results/zk60_a28_app_20261107
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
