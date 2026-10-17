#!/bin/bash
# TINYLLAMA PORT: the computed half of the prediction for the two trained
# two-block bundles, written BEFORE the gate reads either bundle past `load`.
# `zk60_native_rg_predict` reads only the shape and the capture's DECLARED
# per-opening geometry; it is validated first against four committed RUN
# records of the joint-view lane (rung-K4, rung-P2, rung-E32, rung-K8), which
# is what shows the D24 edit moved no frozen prediction.
set -x
S=/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/scripts
B=/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920
K=/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260922_k8
J=/home/victor/wt-zk60-jointview/results
A=/home/victor/zk60-artifacts
P=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017/l2
V="--validate $B/run-i-dense-k4:$J/zk60_native_run_gate_mask/run-i-dense-k4.json \
   --validate $B/run-k-dense-p2:$J/zk60_native_run_gate_p2/run-k-dense-p2.json \
   --validate $B/run-q-dense-e32:$J/zk60_native_run_gate_9c/run-q-dense-e32.json \
   --validate $K/run-s-dense-k8:$J/zk60_native_run_gate_k8/run-s-dense-k8.json"
python3 $S/zk60_native_rg_predict.py --bundle $A/tinyllama-trained-capture-dense-l2 $V --evidence $P --name prediction_tinyllama_l2_dense
python3 $S/zk60_native_rg_predict.py --bundle $A/tinyllama-trained-capture-zero-l2 $V --evidence $P --name prediction_tinyllama_l2_zero
