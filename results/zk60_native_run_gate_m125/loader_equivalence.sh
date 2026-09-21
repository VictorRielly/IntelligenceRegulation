#!/usr/bin/env bash
# ROUND 9, item N1: the /5-run DECODER proved against a /4-run development
# bundle, two ways.
#   (1) member by member: re-encode run-g-dense-s20 with this lane's own
#       encoder, load both, compare every JSON leaf;
#   (2) THROUGH THE WHOLE GATE: the same flags on the /4-run original and on
#       the /5-run copy, leaf-diffed.
# Neither tests the Rust encoder; the Rust lane has its own byte-for-byte
# equality test for that.
set -u
W=/home/victor/wt-zk60-jointview
E=$W/results/zk60_native_run_gate_m125
C=/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920
T=${TMP5RUN:?set TMP5RUN to a scratch directory outside the repository}

python3 $W/scripts/zk60_native_rg_reencode.py \
  --bundle $C/run-g-dense-s20 --work $T/run-g-5run --evidence $E \
  --name loader_equivalence

for pair in "four:$C/run-g-dense-s20" "five:$T/run-g-5run"; do
  tag=${pair%%:*}; dir=${pair#*:}
  python3 $W/scripts/zk60_native_run_gate.py --bundle "$dir" \
    --other $C/run-h-zero-s20 --old $C/run-a-tame \
    --evidence $E --name "loader_equivalence_gate_$tag"
done

python3 $W/scripts/zk60_native_rg_recdiff.py \
  $E/loader_equivalence_gate_four.json $E/loader_equivalence_gate_five.json \
  --out $E/loader_equivalence_gate.diff.json
