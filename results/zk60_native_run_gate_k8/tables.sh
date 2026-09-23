#!/bin/bash
# ROUND 9i, K5: dense against zero at rung-K8 (round 4's comparison, as
# every round since has run it), and rung-K8 against rung-K4 against the
# prediction of ledger R9i.4.
set -x
W=/home/victor/wt-zk60-jointview
P=$W/results/zk60_native_run_gate_k8
python3 $W/scripts/zk60_native_rg_witcmp.py \
  --record $P/run-s-dense-k8.json --label rung-K8-dense --witness dense \
  --record $P/run-t-zero-k8.json  --label rung-K8-zero  --witness all-zero \
  --out $P/witness_comparison_k8_dense_vs_zero.json
python3 $P/k8_vs_k4.py
