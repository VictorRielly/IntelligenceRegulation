#!/bin/bash
# ROUND 9i: the WHOLE gate at rung-K8 (lkv = 3), both bundles, every arm
# (`--full-preimage --mask-cfs`), every control.  `--old run-a/b` is the
# pre-plane-index bundle control CT-4 needs; `--cross-profile run-i/j-k4`
# is a second TAGGED profile for control CH-7 -- rung-K4, the shape with
# one group bit fewer and the same padded layout.
set -x
K=/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260922_k8
B=/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920
W=/home/victor/wt-zk60-jointview
G=$W/scripts/zk60_native_run_gate.py
P=$W/results/zk60_native_run_gate_k8
/usr/bin/time -v python3 $G --full-preimage --mask-cfs --bundle $K/run-s-dense-k8 --other $K/run-t-zero-k8 --old $B/run-a-tame --cross-profile $B/run-i-dense-k4 --evidence $P 2> $P/time-run-s-dense-k8.log
/usr/bin/time -v python3 $G --full-preimage --mask-cfs --bundle $K/run-t-zero-k8 --other $K/run-s-dense-k8 --old $B/run-b-zero --cross-profile $B/run-j-zero-k4 --evidence $P 2> $P/time-run-t-zero-k8.log
