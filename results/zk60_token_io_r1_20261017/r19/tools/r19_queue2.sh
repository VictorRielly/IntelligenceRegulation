#!/bin/bash
# TOKEN ROUND 19: suite -> checks -> freeze (r19_queue.sh's last three steps), launched by hand after the chain's
# mutants were re-judged with the fixed mutcheck.py (rejudge19.sh: all killed as named) and the chain's tree check
# passed. Each step only if the one before ended 0. Marker logs/r19_queue2.done.
source /home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r19/tools/r19_common.sh
grep -q "^ALL-KILLED-AS-NAMED$" $L/rejudge.log || { echo "rejudge" > $L/r19_queue2.done; exit 0; }
for s in suite check freeze; do
  bash $T/tools/r19_$s.sh; echo $? > $L/r19_$s.sh.done
  [ "$(cat $L/r19_$s.done 2>/dev/null)" = "0" ] || { echo "$s $(cat $L/r19_$s.done 2>/dev/null)" > $L/r19_queue2.done; exit 0; }
done
echo 0 > $L/r19_queue2.done
