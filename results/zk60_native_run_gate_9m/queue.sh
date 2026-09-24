#!/bin/bash
# ROUND 9m: the heavy queue, in order, each heavy step under the heavy lock
# (taken per step, so another lane's job can interleave), each with its own
# log and .done marker.  Before each heavy step the available memory is
# logged and, if it is below the step's projected peak plus a margin, the
# step WAITS for it (polling once a minute, at most two hours) rather than
# starting into a shared box that cannot hold it -- the stop rule of R9m.2
# applied at run time.  The tool bytes are FROZEN and the baselines taken
# (`before.sh`) before this is launched.  The leaf diff is CPU-light and
# runs without the lock.
#
# NOT RUN (R9m.2): pass T, the whole-run terminal control families, fits
# both limits (3.55 h, 6.4 GB) and is left out for wall clock only.  Its
# command, for whoever runs it:
#   /usr/bin/time -v python3 -u scripts/zk60_native_rg_m125.py \
#     --bundle /home/victor/zk60-artifacts/m125-capture-dense-l12 \
#     --other /home/victor/zk60-artifacts/m125-capture-zero-l12 \
#     --cross-profile <run-i-dense-k4> --evidence <dir> --name l12-dense-t \
#     --stages load,replay,terminals,commitments,boundary,runcontrols --controls
# and the EVERYTHING pass (6.98 h) fails the 4 h limit.
E=/home/victor/wt-zk60-jointview/results/zk60_native_run_gate_9m
avail_mb() { awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo; }
step() {  # name, need_mb, command...
  local n=$1 need=$2; shift 2
  {
    echo "[$(date '+%F %T')] $n: needs ~${need} MB available"
    free -m
  } >> $E/$n.log
  local waited=0
  while [ "$(avail_mb)" -lt "$need" ] && [ $waited -lt 7200 ]; do
    echo "[$(date '+%F %T')] $n: $(avail_mb) MB available < $need, waiting" >> $E/$n.log
    sleep 60; waited=$((waited + 60))
  done
  if [ "$(avail_mb)" -lt "$need" ]; then
    echo "[$(date '+%F %T')] $n: NOT STARTED, $(avail_mb) MB available after 2 h" >> $E/$n.log
    echo 99 > $E/$n.done
    return
  fi
  flock /tmp/zk-heavy.lock "$@" >> $E/$n.log 2>&1
  echo $? > $E/$n.done
}
rm -f $E/l12-*.done $E/refresh.done $E/repin_diff.done $E/suite.done $E/queue.finished
step l12-dense-a 9000 bash $E/l12.sh a dense
step l12-zero-a 9000 bash $E/l12.sh a zero
step l12-dense-m 3000 bash $E/l12.sh m dense
step l12-zero-m 3000 bash $E/l12.sh m zero
step refresh 3000 bash $E/refresh.sh
python3 $E/repin_diff.py > $E/repin_diff.log 2>&1
echo $? > $E/repin_diff.done
step suite 8000 bash $E/suite.sh
step l12-dense-f 9500 bash $E/l12.sh f dense
echo queue finished > $E/queue.finished
