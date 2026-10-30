#!/bin/bash
# TOKEN ROUND 19b: chain -> suite -> checks -> freeze, each only if the one before ended 0 (its own marker = 0).
# Marker logs/r19b_queue.done = 0 or "<step> <its marker>".
source /home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r19b/tools/r19b_common.sh
for s in chain suite check freeze; do
  bash $T/tools/r19b_$s.sh; echo $? > $L/r19b_$s.sh.done
  [ "$(cat $L/r19b_$s.done 2>/dev/null)" = "0" ] || { echo "$s $(cat $L/r19b_$s.done 2>/dev/null)" > $L/r19b_queue.done; exit 0; }
done
echo 0 > $L/r19b_queue.done
