#!/bin/bash
# ROUND 9c: the prediction at the THREE new shapes, written and committed
# BEFORE the gate is run on any of the six bundles.  Each run is validated
# against three COMMITTED records at three different shapes -- rung-K4,
# rung-P2 and 125M -- so a module that cannot reproduce what is already on
# disk predicts nothing here either.
set -x
B=/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920
A=/home/victor/zk60-artifacts
W=/home/victor/wt-zk60-jointview
P=$W/results/zk60_native_run_gate_9c
V="--validate $B/run-i-dense-k4:$W/results/zk60_native_run_gate_k4/run-i-dense-k4.json \
   --validate $B/run-k-dense-p2:$W/results/zk60_native_run_gate_p2/run-k-dense-p2.json \
   --validate $A/m125-capture-dense-l2:$W/results/zk60_native_run_gate_m125/m125-dense.json"
python3 $W/scripts/zk60_native_rg_predict.py --bundle $B/run-m-dense-c6  $V --evidence $P --name prediction_c6_dense
python3 $W/scripts/zk60_native_rg_predict.py --bundle $B/run-n-zero-c6   $V --evidence $P --name prediction_c6_zero
python3 $W/scripts/zk60_native_rg_predict.py --bundle $A/run-o-dense-w14 $V --evidence $P --name prediction_w14_dense
python3 $W/scripts/zk60_native_rg_predict.py --bundle $A/run-p-zero-w14  $V --evidence $P --name prediction_w14_zero
python3 $W/scripts/zk60_native_rg_predict.py --bundle $B/run-q-dense-e32 $V --evidence $P --name prediction_e32_dense
python3 $W/scripts/zk60_native_rg_predict.py --bundle $B/run-r-zero-e32  $V --evidence $P --name prediction_e32_zero
# ROUND 9c: the same module on the three shapes whose records are already
# committed, so that the THREE NEW DERIVATIONS (correction C-6, the Dom::Tab
# lift, the endpoint's row count) are checked where C-6 is OFF (rung-K4 and
# rung-P2, width 96) as well as where it is ON (125M, width 768).
python3 $W/scripts/zk60_native_rg_predict.py --bundle $B/run-i-dense-k4 --validate $B/run-i-dense-k4:$W/results/zk60_native_run_gate_k4/run-i-dense-k4.json --evidence $P --name prediction_check_k4
python3 $W/scripts/zk60_native_rg_predict.py --bundle $B/run-k-dense-p2 --validate $B/run-k-dense-p2:$W/results/zk60_native_run_gate_p2/run-k-dense-p2.json --evidence $P --name prediction_check_p2
python3 $W/scripts/zk60_native_rg_predict.py --bundle $A/m125-capture-dense-l2 --validate $A/m125-capture-dense-l2:$W/results/zk60_native_run_gate_m125/m125-dense.json --evidence $P --name prediction_check_m125
