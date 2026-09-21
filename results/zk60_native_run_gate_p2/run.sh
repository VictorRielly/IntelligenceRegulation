#!/bin/bash
# ROUND 9b: the WHOLE gate at `rung-P2`, both bundles, every arm round 8
# runs at a development shape -- `--full-preimage` (round 7's stage 11) and
# `--mask-cfs` (round 8's stage 12), which together also give stage 13, the
# JOINT run-wide preimage.  The controls are on by default.
#
# `--old` is a bundle written before the plane-index table (the stage-8
# control that a missing table leaves the channel OPEN) and `--cross-profile`
# is a bundle of a DIFFERENT tagged profile (control CH-7).  rung-P2 has its
# own profile (D17), so run-i-dense-k4 is a cross profile for it.
#
# What this round is about: T, Kv and F sit EXACTLY on their pads here, so
# slots 02, 16 and 18 take the `pad_on == false` arm of the pad rule --
# finding M-F1's arm, which until now only the 125M bundles could reach.
set -x
B=/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920
W=/home/victor/wt-zk60-jointview
G=$W/scripts/zk60_native_run_gate.py
P=$W/results/zk60_native_run_gate_p2
/usr/bin/time -v python3 $G --full-preimage --mask-cfs --bundle $B/run-k-dense-p2 --other $B/run-l-zero-p2 --old $B/run-a-tame --cross-profile $B/run-i-dense-k4 --evidence $P 2> $P/time-run-k-dense-p2.log
/usr/bin/time -v python3 $G --full-preimage --mask-cfs --bundle $B/run-l-zero-p2 --other $B/run-k-dense-p2 --old $B/run-b-zero --cross-profile $B/run-j-zero-k4 --evidence $P 2> $P/time-run-l-zero-p2.log
