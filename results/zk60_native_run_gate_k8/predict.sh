#!/bin/bash
# ROUND 9i: the prediction at rung-K8, written and committed BEFORE the gate
# is run on either rung-K8 bundle with any pin read.  Each run is validated
# against committed records at three shapes -- rung-K4 (the same padded
# layout, one group bit fewer), rung-P2 and rung-E32 -- so a module that
# cannot reproduce what is already on disk predicts nothing here either.
# (The one record that exists at rung-K8 before this script is the
# failing-first probe in `probe/`, which is NOT used as a validation input.)
set -x
K=/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260922_k8
B=/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920
W=/home/victor/wt-zk60-jointview
P=$W/results/zk60_native_run_gate_k8
V="--validate $B/run-i-dense-k4:$W/results/zk60_native_run_gate_mask/run-i-dense-k4.json \
   --validate $B/run-k-dense-p2:$W/results/zk60_native_run_gate_p2/run-k-dense-p2.json \
   --validate $B/run-q-dense-e32:$W/results/zk60_native_run_gate_9c/run-q-dense-e32.json"
python3 $W/scripts/zk60_native_rg_predict.py --bundle $K/run-s-dense-k8 $V --evidence $P --name prediction_k8_dense
python3 $W/scripts/zk60_native_rg_predict.py --bundle $K/run-t-zero-k8  $V --evidence $P --name prediction_k8_zero
