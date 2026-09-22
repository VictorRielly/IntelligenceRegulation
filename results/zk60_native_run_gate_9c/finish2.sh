#!/bin/bash
# ROUND 9c, the closing sequence RUN AGAIN after the last tool edit:
# the second refresh (26 records), its leaf diff, and the whole native
# suite -- which is where the first sequence was killed at 4G.
set -x
P=/home/victor/wt-zk60-jointview/results/zk60_native_run_gate_9c
W=/home/victor/wt-zk60-jointview
flock /tmp/zk-heavy.lock systemd-run --user --scope -q -p MemoryMax=8G -p MemorySwapMax=0 bash $P/refresh2.sh > $P/refresh2.log 2>&1; echo "refresh2 exit=$?"
bash $P/diff2.sh > $P/diff2.log 2>&1; echo "diff2 exit=$?"
systemd-run --user --scope -q -p MemoryMax=4G -p MemorySwapMax=0 python3 -m unittest discover -s $W/tests -p 'test_zk60_native*.py' > $P/tests_native_all.log 2>&1; echo "suite exit=$?"
date
