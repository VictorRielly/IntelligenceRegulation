#!/bin/bash
# Lane B3 T=128 ladder queue: one guarded light job per variant, sequential.
# usage: b3_queue128.sh <variant[:rotseed]>...
D=/home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
for spec in "$@"; do
  v=${spec%%:*}; r=""; lab=$v
  if [ "$spec" != "$v" ]; then r="--rotate ${spec##*:}"; lab=${v}_rot${spec##*:}; fi
  python3 $G run --class light --need-gib 3 --cap-gib 4.5 --label b3-T128-$lab --wait-secs 14400 --max-secs 5400 \
    --log $D/logs/b3-T128-$lab.log --done $D/logs/b3-T128-$lab.done --result-json $D/logs/b3-T128-$lab.guard.json \
    -- python3 $D/b3_ladder.py --variant $v $r --T 128 --site-seqs 3
done
