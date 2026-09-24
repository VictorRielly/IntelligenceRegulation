#!/bin/bash
# ROUND 9m: the COMPUTED half of the prediction for the two TWELVE-block
# 125M run bundles of lane stage 48, written and committed BEFORE the gate
# reads either of them with its pins read.  `zk60_native_rg_predict` reads
# only the shape and the capture's DECLARED per-opening geometry (row, group
# and claim counts) -- no published value.  It is validated first against
# the two committed TWO-block 125M run records (round 9c's re-takes of
# `m125-dense` / `m125-zero`) and two development run records (rung-K4,
# rung-K8), so a prediction that did not reproduce L = 2 to the unit would
# predict nothing at L = 12.  The tool is not edited in this round.
set -x
A=/home/victor/zk60-artifacts
K=/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260922_k8
B=/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920
W=/home/victor/wt-zk60-jointview
E=$W/results/zk60_native_run_gate_9m
V="--validate $A/m125-capture-dense-l2:$W/results/zk60_native_run_gate_m125/m125-dense.json \
   --validate $A/m125-capture-zero-l2:$W/results/zk60_native_run_gate_m125/m125-zero.json \
   --validate $B/run-i-dense-k4:$W/results/zk60_native_run_gate_mask/run-i-dense-k4.json \
   --validate $K/run-s-dense-k8:$W/results/zk60_native_run_gate_k8/run-s-dense-k8.json"
python3 $W/scripts/zk60_native_rg_predict.py --bundle $A/m125-capture-dense-l12 $V --evidence $E --name prediction_l12_dense
echo "dense exit=$?"
python3 $W/scripts/zk60_native_rg_predict.py --bundle $A/m125-capture-zero-l12 $V --evidence $E --name prediction_l12_zero
echo "zero exit=$?"
