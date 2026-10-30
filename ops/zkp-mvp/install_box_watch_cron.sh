#!/bin/bash
# Victor runs this once (D46, 2026-10-30): adds the 5-minute box watch to his user crontab,
# next to the researcher's block. It checks C: space and Windows memory, messages Victor on
# Telegram when one goes low, and releases Linux's file cache when Windows runs short.
# Safe to run twice: it does nothing if the block is already there.
set -euo pipefail
R=/home/victor/IntelligenceRegulation
if crontab -l 2>/dev/null | grep -q 'BEGIN zk60-box-watch'; then
  echo "box watch already installed"; exit 0
fi
{
  crontab -l 2>/dev/null
  echo '# BEGIN zk60-box-watch (D46: C: space and Windows memory; docs/zkmatrix-poc/ZK60_RESOURCE_PROTOCOL.md)'
  echo "*/5 * * * * /usr/bin/nice -n 10 /usr/bin/python3 $R/scripts/zk60_resource_watch.py --once --state $R/results/zk60_resource_guard/watch_state.json --notify --evict-cache >> $R/results/zk60_resource_guard/watch.log 2>&1"
  echo '# END zk60-box-watch'
} | crontab -
crontab -l | sed -n '/BEGIN zk60-box-watch/,/END zk60-box-watch/p'
echo "box watch installed"
