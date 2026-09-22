#!/bin/bash
# ROUND 9c task C: the lane's stage-34 slot-IR export read as a CROSS-CHECK
# of this gate's hand port, at every shape a bundle exists for.
set -x
B=/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920
A=/home/victor/zk60-artifacts
W=/home/victor/wt-zk60-jointview
python3 $W/scripts/zk60_native_rg_slotir.py \
  --pair rung_g:$B/run-g-dense-s20 \
  --pair rung_k4:$B/run-i-dense-k4 \
  --pair rung_p2:$B/run-k-dense-p2 \
  --pair rung_c6:$B/run-m-dense-c6 \
  --pair rung_w14:$A/run-o-dense-w14 \
  --pair rung_e32:$B/run-q-dense-e32 \
  --pair m125:$A/m125-capture-dense-l2 \
  --evidence $W/results/zk60_native_run_gate_9c --name slot_ir_crosscheck
