#!/bin/bash
# ROUND 9l: the heavy queue, in order, each heavy step under the heavy lock
# (taken per step, so another lane's job can interleave), each with its own
# log and .done marker.  The tool bytes are FROZEN and the baselines taken
# (`before.sh`) before this is launched.  The leaf diff is CPU-light and
# runs without the lock.
E=/home/victor/wt-zk60-jointview/results/zk60_native_run_gate_9l
step() {  # name, command...
  local n=$1; shift
  flock /tmp/zk-heavy.lock "$@" > $E/$n.log 2>&1
  echo $? > $E/$n.done
}
rm -f $E/run_rung_g.done $E/m125.done $E/refresh.done $E/repin_diff.done $E/suite.done $E/queue.finished
step run_rung_g bash $E/run_rung_g.sh
step m125 bash $E/m125.sh
step refresh bash $E/refresh.sh
python3 $E/repin_diff.py > $E/repin_diff.log 2>&1
echo $? > $E/repin_diff.done
step suite bash $E/suite.sh
echo queue finished > $E/queue.finished
