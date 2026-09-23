#!/bin/bash
# ROUND 9i, K6: the suites, after the rung-K8 records and the twenty-six
# re-taken records have landed.  Enqueued with a wait on `refresh.done`
# FIRST, so that it can never take the heavy lock ahead of the refresh and
# read stale records.  Three passes, each with its own log:
#   1. the TOY gate's seven modules (round 9h: 217 tests);
#   2. the record guard alone (round 9h: 42 tests);
#   3. the WHOLE `test_zk60_native*.py` suite -- last measured at 530 in
#      round 9c, and not re-run since (R9h.10 item 3 asks for it).
set -x
cd /home/victor/wt-zk60-jointview
E=/home/victor/wt-zk60-jointview/results/zk60_native_run_gate_k8
date
python3 -m unittest tests.test_zk60_native_capture tests.test_zk60_native_gate_record tests.test_zk60_native_joint_view tests.test_zk60_native_mask_commit tests.test_zk60_native_privacy_gate tests.test_zk60_native_terminal_polys tests.test_zk60_native_small_model_groups > $E/suite_toy.log 2>&1
echo "toy suite exit=$?"
python3 -m unittest -v tests.test_zk60_native_gate_record > $E/suite_guard.log 2>&1
echo "record guard exit=$?"
date
python3 -m unittest discover -s tests -p 'test_zk60_native*.py' > $E/suite_native_all.log 2>&1
echo "whole native suite exit=$?"
date
