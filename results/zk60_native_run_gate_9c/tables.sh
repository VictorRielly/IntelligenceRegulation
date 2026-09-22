#!/bin/bash
# ROUND 9c: one comparison table per new shape against rung-P2 and rung-K4,
# with every figure CLASSIFIED (invariant / block count / scales /
# UNEXPLAINED), and dense against zero at each of the three.
set -x
W=/home/victor/wt-zk60-jointview
P=$W/results/zk60_native_run_gate_9c
T=$W/scripts/zk60_native_rg_m125table.py
C=$W/scripts/zk60_native_rg_witcmp.py
# BOTH-ARMS records on both sides: the comparison's `channels` invariant is
# a property of WHICH ARMS RAN, so a default-arm record beside a both-arms
# one breaks it for a reason that is not a shape effect.
K4=$W/results/zk60_native_run_gate_mask/run-i-dense-k4.json
P2=$W/results/zk60_native_run_gate_p2/run-k-dense-p2.json
for s in c6:run-m-dense-c6 w14:run-o-dense-w14 e32:run-q-dense-e32; do
  k=${s%%:*}; b=${s#*:}
  python3 $T --m125 $P/$b.json --dev $K4:rung-K4 --dev $P2:rung-P2 \
     --prediction $P/prediction_${k}_dense.json \
     --out $P/comparison_table_${k}.json
done
python3 $C --record $P/run-m-dense-c6.json --label rung-C6-dense --witness dense \
          --record $P/run-n-zero-c6.json  --label rung-C6-zero  --witness all-zero \
          --out $P/witness_comparison_c6_dense_vs_zero.json
python3 $C --record $P/run-o-dense-w14.json --label rung-W14-dense --witness dense \
          --record $P/run-p-zero-w14.json  --label rung-W14-zero  --witness all-zero \
          --out $P/witness_comparison_w14_dense_vs_zero.json
python3 $C --record $P/run-q-dense-e32.json --label rung-E32-dense --witness dense \
          --record $P/run-r-zero-e32.json  --label rung-E32-zero  --witness all-zero \
          --out $P/witness_comparison_e32_dense_vs_zero.json
