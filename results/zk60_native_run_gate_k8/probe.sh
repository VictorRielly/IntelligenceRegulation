#!/bin/bash
# ROUND 9i, FAILING FIRST: the gate as it stood at `836f717` (round 9h's
# tools, nothing edited) pointed at the two rung-K8 bundles, default arms,
# every control.  Its record goes to `probe/` and is NOT a record of record:
# it is the evidence of which refusals the unread pins raise before anything
# was read or re-pinned.
set -x
K=/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260922_k8
B=/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920
W=/home/victor/wt-zk60-jointview
G=$W/scripts/zk60_native_run_gate.py
P=$W/results/zk60_native_run_gate_k8/probe
python3 $G --bundle $K/run-s-dense-k8 --other $K/run-t-zero-k8 --old $B/run-a-tame --cross-profile $B/run-i-dense-k4 --evidence $P
echo "exit $?"
