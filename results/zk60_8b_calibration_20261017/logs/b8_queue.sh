#!/bin/bash
# Lane B8 (coordinator 01:4xZ): 8B token I/O (R3) for b7_T128 (build) then b7_T32 (reuse), AFTER the b7 exports
# (logs/b7_serial.done) and behind hold #3 (logs/b7_hold3.py). ONE guarded light job at a time.
D=/home/victor/IntelligenceRegulation/results/zk60_8b_calibration_20261017
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
hold() { until python3 $D/logs/b7_hold3.py >> $D/logs/b7_hold3.log 2>&1; do sleep 60; done; }
until [ -f $D/logs/b7_serial.done ]; do sleep 30; done
hold
echo "[b8 $(date -u +%H:%M:%SZ)] start token_io build b7_T128"
python3 $G run --class light --need-gib 4 --cap-gib 5 --label b8-tio-b7_T128 --wait-secs 21600 --max-secs 7200 \
  --log $D/logs/b8-tio-b7_T128.log --done $D/logs/b8-tio-b7_T128.done --result-json $D/logs/b8-tio-b7_T128.guard.json \
  -- python3 $D/b8_token_io.py build $D/export/llama3_8b_pg_rot1_b7_T128 $D/runs/llama3_8b_pg_rot1_b7_T128
hold
echo "[b8 $(date -u +%H:%M:%SZ)] start token_io reuse b7_T32"
python3 $G run --class light --need-gib 3 --cap-gib 4 --label b8-tio-b7_T32 --wait-secs 21600 --max-secs 7200 \
  --log $D/logs/b8-tio-b7_T32.log --done $D/logs/b8-tio-b7_T32.done --result-json $D/logs/b8-tio-b7_T32.guard.json \
  -- python3 $D/b8_token_io.py reuse $D/export/llama3_8b_pg_rot1_b7_T32 $D/runs/llama3_8b_pg_rot1_b7_T32_cal128 \
     $D/export/llama3_8b_pg_rot1_b7_T128/token_io
