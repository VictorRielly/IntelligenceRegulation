#!/bin/bash
# ROUND 9: each refreshed record diffed LEAF BY LEAF against the committed
# bytes in before/, then classified.
set -x
W=/home/victor/wt-zk60-jointview
E=$W/results/zk60_native_run_gate_m125
mkdir -p $E/diffs
for p in \
  zk60_native_run_gate/run-a-tame \
  zk60_native_run_gate/run-b-zero \
  zk60_native_run_gate_planeindex/run-c-tame \
  zk60_native_run_gate_planeindex/run-d-zero \
  zk60_native_run_gate_tagged/run-e-tame-tagged \
  zk60_native_run_gate_tagged/run-f-zero-tagged \
  zk60_native_run_gate_s20/run-g-dense-s20 \
  zk60_native_run_gate_s20/run-h-zero-s20 \
  zk60_native_run_gate_k4/run-i-dense-k4 \
  zk60_native_run_gate_k4/run-j-zero-k4 ; do
  b=$(basename $p)
  python3 $W/scripts/zk60_native_rg_recdiff.py "$E/before/$b.json" "$W/results/$p.json" --out "$E/diffs/$b.diff.json"
done
python3 $W/scripts/zk60_native_rg_recclass.py $E/diffs/*.diff.json --out $E/all_ten_bundles_unchanged.json
