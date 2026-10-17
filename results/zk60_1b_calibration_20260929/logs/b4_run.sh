#!/bin/bash
# Lane B4: one guarded light run of b3_ladder.py.
# usage: b4_run.sh <label> <need_gib> <cap_gib> <ladder args...>
D=/home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
lab=$1; need=$2; cap=$3; shift 3
python3 $G run --class light --need-gib $need --cap-gib $cap --label b4-$lab --wait-secs 21600 --max-secs 10800 \
  --log $D/logs/b4-$lab.log --done $D/logs/b4-$lab.done --result-json $D/logs/b4-$lab.guard.json \
  -- python3 $D/b3_ladder.py "$@"
