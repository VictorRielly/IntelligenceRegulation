#!/bin/bash
# ROUND 9j: the WHOLE gate on the two STANDALONE rung-G block bundles of lane
# stage 45, every arm (`--full-preimage --mask-cfs`), every control.  As in
# round 9i: `--old run-a/b` is the pre-plane-index RUN bundle controls CT-4
# and CH-6 need; `--cross-profile run-i/j-k4` a second TAGGED profile for
# CH-7 (rung-K4).  `--other` is the sibling block bundle (control C5b).
set -x
G=/home/victor/wt-zk60-block125m/results/zk60_block_captures_20260923/rung-g
B=/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920
W=/home/victor/wt-zk60-jointview
T=$W/scripts/zk60_native_run_gate.py
P=$W/results/zk60_native_run_gate_block
/usr/bin/time -v python3 $T --full-preimage --mask-cfs --bundle $G/rung-g-dense --other $G/rung-g-zero --old $B/run-a-tame --cross-profile $B/run-i-dense-k4 --evidence $P --name block-rung-g-dense 2> $P/time-block-rung-g-dense.log
/usr/bin/time -v python3 $T --full-preimage --mask-cfs --bundle $G/rung-g-zero --other $G/rung-g-dense --old $B/run-b-zero --cross-profile $B/run-j-zero-k4 --evidence $P --name block-rung-g-zero 2> $P/time-block-rung-g-zero.log
