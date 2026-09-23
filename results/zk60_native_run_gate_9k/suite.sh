#!/bin/bash
# ROUND 9k: the suites, after every re-taken record has landed (enqueued on
# the heavy lock AFTER the refresh).  No systemd scope (no user bus on this
# box).  Three passes, each with its own log, as rounds 9i and 9j.
set -x
W=/home/victor/wt-zk60-jointview
E=$W/results/zk60_native_run_gate_9k
cd $W
date
python3 -m unittest tests.test_zk60_native_capture tests.test_zk60_native_gate_record tests.test_zk60_native_joint_view tests.test_zk60_native_mask_commit tests.test_zk60_native_privacy_gate tests.test_zk60_native_terminal_polys tests.test_zk60_native_small_model_groups > $E/suite_toy.log 2>&1
echo "toy suite exit=$?"
python3 -m unittest -v tests.test_zk60_native_gate_record > $E/suite_guard.log 2>&1
echo "record guard exit=$?"
date
/usr/bin/time -v python3 -m unittest discover -s tests -p 'test_zk60_native*.py' > $E/suite_native_all.log 2>&1
echo "whole native suite exit=$?"
date
