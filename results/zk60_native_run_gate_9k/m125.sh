#!/bin/bash
# ROUND 9k: C3c at 125M, CHEAPLY -- the staged driver on each standalone 125M
# block bundle with only the stages the control needs (load, replay, the
# per-commitment views, stage 4 for the honest whole block, then the
# run-control stage, which fires the block family with C3c, the hash-rule
# family and round 9's M9-1 / M9-2).  No terminals, no arms, and NOT round
# 9j's everything pass.  Two NEW records; round 9j's four 125M block records
# are not touched.  --cross-profile as round 9j's pass B (CH-7).
set -x
M=/home/victor/zk60-artifacts/block-captures-20260923
B=/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920
W=/home/victor/wt-zk60-jointview
D=$W/scripts/zk60_native_rg_m125.py
E=$W/results/zk60_native_run_gate_9k
S="load,replay,commitments,boundary,runcontrols"
/usr/bin/time -v python3 $D --bundle $M/m125-dense --other $M/m125-zero --stages $S --cross-profile $B/run-i-dense-k4 --evidence $E --name block-m125-dense-c3c 2> $E/time-block-m125-dense-c3c.log
/usr/bin/time -v python3 $D --bundle $M/m125-zero --other $M/m125-dense --stages $S --cross-profile $B/run-j-zero-k4 --evidence $E --name block-m125-zero-c3c 2> $E/time-block-m125-zero-c3c.log
