#!/bin/bash
# ROUND 9c: the WHOLE gate at `rung-E32`, both bundles, every arm.
set -x
B=/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920
W=/home/victor/wt-zk60-jointview
G=$W/scripts/zk60_native_run_gate.py
P=$W/results/zk60_native_run_gate_9c
/usr/bin/time -v python3 $G --full-preimage --mask-cfs --bundle $B/run-q-dense-e32 --other $B/run-r-zero-e32 --old $B/run-a-tame --cross-profile $B/run-m-dense-c6 --evidence $P 2> $P/time-run-q-dense-e32.log
/usr/bin/time -v python3 $G --full-preimage --mask-cfs --bundle $B/run-r-zero-e32 --other $B/run-q-dense-e32 --old $B/run-b-zero --cross-profile $B/run-n-zero-c6 --evidence $P 2> $P/time-run-r-zero-e32.log
