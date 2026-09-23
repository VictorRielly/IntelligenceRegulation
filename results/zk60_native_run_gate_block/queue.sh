#!/bin/bash
# ROUND 9j: the whole heavy queue, in order, each step under the heavy lock
# (taken per step, so another lane's job can interleave), each with its own
# log and .done marker.  The tool bytes are FROZEN before this is launched.
P=/home/victor/wt-zk60-jointview/results/zk60_native_run_gate_block
step() {  # name, command...
  local n=$1; shift
  flock /tmp/zk-heavy.lock "$@" > $P/$n.log 2>&1
  echo $? > $P/$n.done
}
rm -f $P/run_rung_g.done $P/m125_a.done $P/refresh.done $P/m125_b.done $P/m125_c.done $P/suite.done
step run_rung_g bash $P/run_rung_g.sh
step m125_a bash $P/m125.sh a
step refresh bash /home/victor/wt-zk60-jointview/results/zk60_native_run_gate_block/refresh.sh
step m125_b bash $P/m125.sh b
step m125_c bash $P/m125.sh c
step suite bash $P/suite.sh
echo queue finished > $P/queue.finished
