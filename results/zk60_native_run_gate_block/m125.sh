#!/bin/bash
# ROUND 9j: the gate at 125M on the two STANDALONE block bundles of lane stage
# 45, through the staged driver (each stage's wall clock and peak RSS), one
# bundle at a time.  Pass A is the record of record (round 9's (a)-(d) stage
# list, no controls -- ~3 min at 125M for a two-block run); pass B is the
# dense bundle through EVERY stage and EVERY control (round 9c's
# `dense-everything`; CT-4 has no --old here and is skipped by name);
# pass C is the zero bundle's arms without controls, for the entry counts.
set -x
M=/home/victor/zk60-artifacts/block-captures-20260923
B=/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920
W=/home/victor/wt-zk60-jointview
D=$W/scripts/zk60_native_rg_m125.py
P=$W/results/zk60_native_run_gate_block
A="load,replay,hash,terminals,commitments,boundary,preimage,channels"
ALL="load,replay,hash,terminals,commitments,boundary,preimage,fullpreimage,mask,joint,runcontrols,channels"
case "$1" in
  a) /usr/bin/time -v python3 $D --bundle $M/m125-dense --other $M/m125-zero --stages $A --evidence $P --name block-m125-dense 2> $P/time-block-m125-dense.log
     /usr/bin/time -v python3 $D --bundle $M/m125-zero --other $M/m125-dense --stages $A --evidence $P --name block-m125-zero 2> $P/time-block-m125-zero.log ;;
  b) /usr/bin/time -v python3 $D --bundle $M/m125-dense --other $M/m125-zero --stages $ALL --controls --cross-profile $B/run-i-dense-k4 --evidence $P --name block-m125-dense-everything 2> $P/time-block-m125-dense-everything.log ;;
  c) /usr/bin/time -v python3 $D --bundle $M/m125-zero --other $M/m125-dense --stages load,replay,commitments,boundary,preimage,fullpreimage,mask,joint,channels --evidence $P --name block-m125-zero-arms 2> $P/time-block-m125-zero-arms.log ;;
esac
