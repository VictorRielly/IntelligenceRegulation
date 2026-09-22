#!/bin/bash
# ROUND 9c: the WHOLE gate at `rung-W14`, both bundles, every arm.  The row
# width is 2^14 and the encoded cube 2^16, so the preimage arm re-encodes
# rows sixteen times as wide as any earlier development shape's.
set -x
B=/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920
A=/home/victor/zk60-artifacts
W=/home/victor/wt-zk60-jointview
G=$W/scripts/zk60_native_run_gate.py
P=$W/results/zk60_native_run_gate_9c
/usr/bin/time -v python3 $G --full-preimage --mask-cfs --bundle $A/run-o-dense-w14 --other $A/run-p-zero-w14 --old $B/run-a-tame --cross-profile $B/run-q-dense-e32 --evidence $P 2> $P/time-run-o-dense-w14.log
/usr/bin/time -v python3 $G --full-preimage --mask-cfs --bundle $A/run-p-zero-w14 --other $A/run-o-dense-w14 --old $B/run-b-zero --cross-profile $B/run-r-zero-e32 --evidence $P 2> $P/time-run-p-zero-w14.log
