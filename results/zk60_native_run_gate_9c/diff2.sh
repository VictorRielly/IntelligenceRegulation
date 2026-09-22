#!/bin/bash
# ROUND 9c, the SECOND refresh's leaf diff: all TWENTY-SIX records against
# the committed bytes, classified.  An UNCLASSIFIED leaf is the result.
set -x
W=/home/victor/wt-zk60-jointview
E=$W/results/zk60_native_run_gate_9c
mkdir -p $E/diffs2
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
  zk60_native_run_gate_k4/run-j-zero-k4 \
  zk60_native_run_gate_p2/run-k-dense-p2 \
  zk60_native_run_gate_p2/run-l-zero-p2 \
  zk60_native_run_gate_9c/run-m-dense-c6 \
  zk60_native_run_gate_9c/run-n-zero-c6 \
  zk60_native_run_gate_9c/run-o-dense-w14 \
  zk60_native_run_gate_9c/run-p-zero-w14 \
  zk60_native_run_gate_9c/run-q-dense-e32 \
  zk60_native_run_gate_9c/run-r-zero-e32 ; do
  b=$(basename $p)
  python3 $W/scripts/zk60_native_rg_recdiff.py "$E/before2/$b.json" "$W/results/$p.json" --out "$E/diffs2/$b.diff.json"
done
for b in run-g-dense-s20 run-h-zero-s20 run-i-dense-k4 run-j-zero-k4 ; do
  python3 $W/scripts/zk60_native_rg_recdiff.py "$E/before2/pre-$b.json" "$W/results/zk60_native_run_gate_preimage/$b.json" --out "$E/diffs2/pre-$b.diff.json"
  python3 $W/scripts/zk60_native_rg_recdiff.py "$E/before2/mask-$b.json" "$W/results/zk60_native_run_gate_mask/$b.json" --out "$E/diffs2/mask-$b.diff.json"
done
python3 $W/scripts/zk60_native_rg_recclass.py $E/diffs2/*.diff.json --out $E/all_twentysix_records_unchanged.json
