#!/bin/bash
# Lane B5: after b5_serial.sh (one guarded job at a time): the layer-1 score-class check.
D=/home/victor/IntelligenceRegulation/results/zk60_8b_calibration_20261017
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
until [ -f $D/logs/b5_serial.done ]; do sleep 30; done
python3 $G run --class light --need-gib 3.5 --cap-gib 4.5 --label b5-layer1 --wait-secs 21600 --max-secs 3600 \
  --log $D/logs/b5-layer1.log --done $D/logs/b5-layer1.done --result-json $D/logs/b5-layer1.guard.json \
  -- env ZK60_MODEL=llama3-8b python3 $D/b5_layer1.py
echo done > $D/logs/b5_serial2.done
