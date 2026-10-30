#!/bin/bash
# gate round 22 item 3, chain A (RUNG captures, light, beside anything per the lean rule): NL-1 S1-S5 on the 12
# classifier slots and the 7 R13-changed block slots, then the terminal surjection with TS-1. Declarations from
# the dev runs (round22/item3/dev/): NL 0.23 GiB -> 0.5 / 1.0; surjection 0.88 GiB -> 1.1 / 1.5.
S=/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/r22-item3
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017/round22/item3
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
W=/home/victor/IntelligenceRegulation/results/zk60_guard_fix_20261021/WINDOW_HOLD
C=/home/victor/zk60-artifacts/token-io/captures
cd /tmp
g() { # name class need cap max -- cmd
  local n=$1 cl=$2 need=$3 cap=$4 mx=$5; shift 6
  while [ -e $W ]; do sleep 30; done
  python3 $G run --class $cl --need-gib $need --cap-gib $cap --label gate22-item3-$n --wait-secs 7200 --max-secs $mx \
    --log $E/logs/$n.log --done $E/logs/$n.guard.done --result-json $E/logs/$n.guard.json -- "$@"
  echo $? > $E/logs/$n.exit
  date -u +%FT%TZ >> $E/logs/$n.exit
}
g nl-rung-values light 0.5 1.0 1800 -- /usr/bin/env OPENBLAS_NUM_THREADS=1 python3 -B $S/zk60_r22_classnl.py \
  --bundle $C/classify-r13-rung-L2-v1-r17-values --evidence $E --name nl-rung-L2-v1-r17-values
g nl-rung-short1 light 0.5 1.0 1800 -- /usr/bin/env OPENBLAS_NUM_THREADS=1 python3 -B $S/zk60_r22_classnl.py \
  --bundle $C/classify-r13-rung-L2-v1-short1 --evidence $E --name nl-rung-L2-v1-short1 --parts classifier
g nl-rung-vtie light 0.5 1.0 1800 -- /usr/bin/env OPENBLAS_NUM_THREADS=1 python3 -B $S/zk60_r22_classnl.py \
  --bundle $C/classify-r13-rung-L2-vtie --evidence $E --name nl-rung-L2-vtie --parts classifier
touch $E/logs/chainA.nl.done
g ts-rung-values light 1.1 1.5 5400 -- /usr/bin/env OPENBLAS_NUM_THREADS=1 python3 -B $S/zk60_r22_classts.py \
  --bundle $C/classify-r13-rung-L2-v1-r17-values --evidence $E --name ts-rung-L2-v1-r17-values --block-stages 1,2
g ts-rung-short1 light 1.1 1.5 2400 -- /usr/bin/env OPENBLAS_NUM_THREADS=1 python3 -B $S/zk60_r22_classts.py \
  --bundle $C/classify-r13-rung-L2-v1-short1 --evidence $E --name ts-rung-L2-v1-short1
date -u +%FT%TZ > $E/logs/chainA.done
