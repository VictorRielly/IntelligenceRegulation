#!/bin/bash
# ROUND 6 (2026-09-21): every in-scope record, diffed LEAF BY LEAF against
# the committed bytes taken into `before/` before any run, then every
# differing leaf classified.  A leaf that fits no class is UNCLASSIFIED and
# the classifier exits nonzero, which is the only interesting outcome.
set -x
W=/home/victor/wt-zk60-jointview
D=$W/results/zk60_native_run_gate_runpins
declare -A DIR=(
  [run-a-tame]=zk60_native_run_gate
  [run-b-zero]=zk60_native_run_gate
  [run-c-tame]=zk60_native_run_gate_planeindex
  [run-d-zero]=zk60_native_run_gate_planeindex
  [run-e-tame-tagged]=zk60_native_run_gate_tagged
  [run-f-zero-tagged]=zk60_native_run_gate_tagged
  [run-g-dense-s20]=zk60_native_run_gate_s20
  [run-h-zero-s20]=zk60_native_run_gate_s20
  [run-i-dense-k4]=zk60_native_run_gate_k4
  [run-j-zero-k4]=zk60_native_run_gate_k4
)
mkdir -p $D/diffs
for b in "${!DIR[@]}"; do
  python3 $W/scripts/zk60_native_rg_recdiff.py \
    $D/before/$b.json $W/results/${DIR[$b]}/$b.json --out $D/diffs/$b.diff.json
done
python3 $W/scripts/zk60_native_rg_recclass.py $D/diffs/*.diff.json \
  --out $D/all_ten_bundles_unchanged.json
