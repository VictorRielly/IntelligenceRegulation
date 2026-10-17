#!/bin/bash
# usage: b3_queue.sh <variant>... ; one guarded light job per variant, sequential
for v in "$@"; do
  python3 /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py run --class light --need-gib 2.5 --cap-gib 3.5 --label b3-ladder-$v --wait-secs 7200 --max-secs 3600     --log /home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929/logs/b3-ladder-$v.log --done /home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929/logs/b3-ladder-$v.done --result-json /home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929/logs/b3-ladder-$v.guard.json     -- python3 /home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929/b3_ladder.py --variant $v --T 32
done
