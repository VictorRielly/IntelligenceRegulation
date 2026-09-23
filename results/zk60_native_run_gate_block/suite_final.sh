#!/bin/bash
# ROUND 9j: the WHOLE test_zk60_native*.py suite again, after the eight
# channel-count assertions of rounds 3-9i were moved deliberately (status
# page row 26's regrade: argued +1, open -1).  The toy subset and the record
# guard did not change and are not re-run (suite_toy.log, suite_guard.log).
set -x
W=/home/victor/wt-zk60-jointview
E=$W/results/zk60_native_run_gate_block
cd $W
date
/usr/bin/time -v python3 -m unittest discover -s tests -p 'test_zk60_native*.py' > $E/suite_native_all_final.log 2>&1
echo "whole native suite exit=$?"
date
