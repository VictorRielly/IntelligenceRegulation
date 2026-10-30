#!/bin/bash
# TOKEN ROUND 19: chain -> suite -> checks -> freeze, each only if the one before ended 0. Marker logs/r19_queue.done.
source /home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r19/tools/r19_common.sh
for s in chain suite check freeze; do
  bash $T/tools/r19_$s.sh; echo $? > $L/r19_$s.sh.done
  [ "$(cat $L/r19_$s.done 2>/dev/null)" = "0" ] || { echo "$s $(cat $L/r19_$s.done 2>/dev/null)" > $L/r19_queue.done; exit 0; }
done
echo 0 > $L/r19_queue.done
