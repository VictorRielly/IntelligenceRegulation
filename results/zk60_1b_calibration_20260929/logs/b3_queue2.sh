#!/bin/bash
# Lane B3 ladder queue: one guarded light job per variant, sequential.
# usage: b3_queue2.sh <variant[:rotseed]>...
D=/home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
for spec in "$@"; do
  v=${spec%%:*}; r=""; lab=$v
  if [ "$spec" != "$v" ]; then r="--rotate ${spec##*:}"; lab=${v}_rot${spec##*:}; fi
  python3 $G run --class light --need-gib 2.5 --cap-gib 3.5 --label b3-L-$lab --wait-secs 10800 --max-secs 3600 \
    --log $D/logs/b3-L-$lab.log --done $D/logs/b3-L-$lab.done --result-json $D/logs/b3-L-$lab.guard.json \
    -- python3 $D/b3_ladder.py --variant $v $r --T 32
done
