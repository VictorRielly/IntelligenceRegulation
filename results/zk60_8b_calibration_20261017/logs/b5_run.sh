#!/bin/bash
# Lane B5: one guarded light run of b5_8b.py. usage: b5_run.sh <label> <need> <cap> <args...>
D=/home/victor/IntelligenceRegulation/results/zk60_8b_calibration_20261017
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
lab=$1; need=$2; cap=$3; shift 3
# B6 (14:59Z): the whole-model 'none' baseline equals B5 T32's FineWeb domain (same words, same sequences);
# run it on the first 2 layers only, for the layer-1 isolated baseline on the same FineWeb sequences.
if [ "$lab" = b6_l1_none ]; then set -- "$@" --layers 2; fi
# B6 (20:02Z): the B6-2 T=32 runs measure 3.01 GiB peak RSS (b5-b6_l1_s16); declare 3.5 / 4.5 (measured + margin)
case "$lab" in b6_l1_*) need=3.5; cap=4.5 ;; esac
# Holds #1 (privacy job admission) and #2 (heavy queue) are past. Hold #3 (2026-10-18 01:4xZ): no new guarded job
# until the privacy gate's L22 chain has finished (r5b/light_queue.finished, no tl-r5b-l22-* live) or 05:30 UTC.
until python3 $D/logs/b7_hold3.py >> $D/logs/b7_hold3.log 2>&1; do
  sleep 60
done
echo "[b5_run $(date -u +%H:%M:%SZ)] hold #3 released for b5-$lab (need $need / cap $cap)"
python3 $G run --class light --need-gib $need --cap-gib $cap --label b5-$lab --wait-secs 21600 --max-secs 43200 \
  --log $D/logs/b5-$lab.log --done $D/logs/b5-$lab.done --result-json $D/logs/b5-$lab.guard.json \
  -- python3 $D/b5_8b.py "$@"
