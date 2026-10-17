#!/bin/bash
# Lane B5: one guarded light run of b5_8b.py. usage: b5_run.sh <label> <need> <cap> <args...>
D=/home/victor/IntelligenceRegulation/results/zk60_8b_calibration_20261017
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
lab=$1; need=$2; cap=$3; shift 3
# B6 (14:59Z): the whole-model 'none' baseline equals B5 T32's FineWeb domain (same words, same sequences);
# run it on the first 2 layers only, for the layer-1 isolated baseline on the same FineWeb sequences.
if [ "$lab" = b6_l1_none ]; then set -- "$@" --layers 2; fi
python3 $G run --class light --need-gib $need --cap-gib $cap --label b5-$lab --wait-secs 21600 --max-secs 43200 \
  --log $D/logs/b5-$lab.log --done $D/logs/b5-$lab.done --result-json $D/logs/b5-$lab.guard.json \
  -- python3 $D/b5_8b.py "$@"
