#!/bin/bash
# ROUND 9k: the WHOLE gate on the two STANDALONE rung-G block bundles, with
# round 9j's command lines unchanged (results/zk60_native_run_gate_block/
# run_rung_g.sh): every arm, every control, now including C3c.  The records
# are re-taken IN PLACE (the recorded arms read them there); the time logs
# land in this round's directory so round 9j's stay as they were.
set -x
G=/home/victor/wt-zk60-block125m/results/zk60_block_captures_20260923/rung-g
B=/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920
W=/home/victor/wt-zk60-jointview
T=$W/scripts/zk60_native_run_gate.py
P=$W/results/zk60_native_run_gate_block
E=$W/results/zk60_native_run_gate_9k
/usr/bin/time -v python3 $T --full-preimage --mask-cfs --bundle $G/rung-g-dense --other $G/rung-g-zero --old $B/run-a-tame --cross-profile $B/run-i-dense-k4 --evidence $P --name block-rung-g-dense 2> $E/time-block-rung-g-dense.log
/usr/bin/time -v python3 $T --full-preimage --mask-cfs --bundle $G/rung-g-zero --other $G/rung-g-dense --old $B/run-b-zero --cross-profile $B/run-j-zero-k4 --evidence $P --name block-rung-g-zero 2> $E/time-block-rung-g-zero.log
