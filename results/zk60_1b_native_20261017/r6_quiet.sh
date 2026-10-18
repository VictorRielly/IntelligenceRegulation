#!/bin/bash
# NATIVE LANE R6 item 2: a QUIET-BOX re-measurement of the 8B T32 and T128
# stacks with the frozen R5b CLI. Each run starts only when the guard's
# `status` shows NO guarded job live and the heavy lock free; afterwards the
# guard history is scanned for any job that overlapped it, and the result is
# labelled "quiet box" or "shared box" accordingly (r6_quiet_label.py).
set -u
D=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
wait_quiet() {
  until s=$(python3 $G status 2>&1); ! echo "$s" | grep -q "^  job " && echo "$s" | grep -q "LOCKS heavy free"; do sleep 30; done
  echo "quiet at $(date -u +%H:%M:%S)"
}
wait_quiet
TAG=-quiet VNEED=2.5 VCAP=8 $D/r5b_stack.sh /home/victor/IntelligenceRegulation/results/zk60_8b_calibration_20261017/export/llama3_8b_pg_rot1_T32 ho00 6 9 4
python3 -B $D/r6_quiet_label.py $D/r5b/stack-llama3_8b_pg_rot1_T32-ho00-cpu-quiet
wait_quiet
TAG=-quiet VNEED=3 VCAP=8 $D/r5b_stack.sh /home/victor/IntelligenceRegulation/results/zk60_8b_calibration_20261017/export/llama3_8b_pg_rot1_b6_T128 ho00 7.5 10.5 0
python3 -B $D/r6_quiet_label.py $D/r5b/stack-llama3_8b_pg_rot1_b6_T128-ho00-cpu-quiet
