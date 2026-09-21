#!/bin/bash
# ROUND 8 (2026-09-21): the three suites, run AFTER the run of record has
# written its evidence (this script is enqueued on the same heavy lock, so
# it self-starts when run2 releases it).
set -x
W=/home/victor/wt-zk60-jointview
D=$W/results/zk60_native_run_gate_mask
python3 -m unittest discover -s $W/tests -p 'test_zk60_native_run_gate_mask.py' -v > $D/tests_mask.log 2>&1
python3 -m unittest discover -s $W/tests -p 'test_zk60_native_run_gate*.py' -v > $D/tests_run_gate_all.log 2>&1
python3 -m unittest discover -s $W/tests -p 'test_zk60_native*.py' -v > $D/tests_native_all.log 2>&1
tail -3 $D/tests_mask.log
tail -3 $D/tests_run_gate_all.log
tail -3 $D/tests_native_all.log
