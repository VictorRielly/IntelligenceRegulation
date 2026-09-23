#!/bin/bash
# ROUND 9j: the prediction for the four STANDALONE shaped block bundles of
# lane stage 45, written and committed BEFORE the gate reads any of them with
# its pins read.  `zk60_native_rg_predict` reads only the shape and the
# capture's DECLARED per-opening geometry (row, group and claim counts); it
# is validated first against committed RUN records at four shapes (rung-K4,
# rung-P2, rung-E32, rung-K8), so the round-9j edits to it (the frame in
# place of segments, no position tag, the endpoint planes as the identified
# rows) are shown not to move a single run prediction.
set -x
G=/home/victor/wt-zk60-block125m/results/zk60_block_captures_20260923/rung-g
M=/home/victor/zk60-artifacts/block-captures-20260923
K=/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260922_k8
B=/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920
W=/home/victor/wt-zk60-jointview
P=$W/results/zk60_native_run_gate_block
V="--validate $B/run-i-dense-k4:$W/results/zk60_native_run_gate_mask/run-i-dense-k4.json \
   --validate $B/run-k-dense-p2:$W/results/zk60_native_run_gate_p2/run-k-dense-p2.json \
   --validate $B/run-q-dense-e32:$W/results/zk60_native_run_gate_9c/run-q-dense-e32.json \
   --validate $K/run-s-dense-k8:$W/results/zk60_native_run_gate_k8/run-s-dense-k8.json"
python3 $W/scripts/zk60_native_rg_predict.py --bundle $G/rung-g-dense $V --evidence $P --name prediction_block_rung_g_dense
python3 $W/scripts/zk60_native_rg_predict.py --bundle $G/rung-g-zero  $V --evidence $P --name prediction_block_rung_g_zero
python3 $W/scripts/zk60_native_rg_predict.py --bundle $M/m125-dense   $V --evidence $P --name prediction_block_m125_dense
python3 $W/scripts/zk60_native_rg_predict.py --bundle $M/m125-zero    $V --evidence $P --name prediction_block_m125_zero
