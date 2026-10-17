#!/bin/bash
# Lane B3 export run: b3_export.sh <variant> [rotseed]
D=/home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
v=$1; r=""; lab=$v
if [ -n "$2" ]; then r="--rotate $2"; lab=${v}_rot$2; fi
python3 $G run --class light --need-gib 2.5 --cap-gib 3.5 --label b3-X-$lab --wait-secs 10800 --max-secs 3600 \
  --log $D/logs/b3-X-$lab.log --done $D/logs/b3-X-$lab.done --result-json $D/logs/b3-X-$lab.guard.json \
  -- python3 $D/b3_ladder.py --variant $v $r --T 32 --tag export --export --export-seqs 2
