#!/bin/bash
# ROUND 9c, the closing sequence, run detached so it survives the session:
# wait for the three whole-gate passes, then the comparison tables, the
# refresh of the eighteen records of record under this round's tool bytes,
# the leaf diff and its classification, and the whole native suite.
set -x
P=/home/victor/wt-zk60-jointview/results/zk60_native_run_gate_9c
W=/home/victor/wt-zk60-jointview
until [ -f $P/run_c6b.done ] && [ -f $P/run_e32.done ] && [ -f $P/run_w14.done ]; do sleep 60; done
date
bash $P/tables.sh > $P/tables.log 2>&1; echo "tables exit=$?"
flock /tmp/zk-heavy.lock systemd-run --user --scope -q -p MemoryMax=8G -p MemorySwapMax=0 bash $P/refresh.sh > $P/refresh.log 2>&1; echo "refresh exit=$?"
bash $P/diff.sh > $P/diff.log 2>&1; echo "diff exit=$?"
systemd-run --user --scope -q -p MemoryMax=4G -p MemorySwapMax=0 python3 -m unittest discover -s $W/tests -p 'test_zk60_native*.py' > $P/tests_native_all.log 2>&1; echo "suite exit=$?"
date
