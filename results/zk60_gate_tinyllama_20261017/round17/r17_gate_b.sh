#!/bin/bash
# PRIVACY GATE lane, gate round 17, queue B: frozen tools v20
# (manifest f3cb140b...) on the R-C1 classifier rung captures:
# classify-rung-L2-v0 classify-rung-L2-v1 classify-rung-L2-vtie
# Each: classgate with controls and the full preimage. Declarations from the
# dev run's measured peak (0.28 GiB, 582 s at L1) plus a margin; a hold-file
# check before each job (EV/HOLD).
. /home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017/round17/r17_common.sh
cd /tmp
python3 $E/v4/freeze.py check $E/gate-tinyllama.tools.frozen.v20.sha256 $GT/frozen_v20 > $P/r17_gate_b.toolcheck 2>&1 || { echo "TOOLS MOVED" > $P/r17_gate_b.finished; exit 4; }
for c in classify-rung-L2-v0 classify-rung-L2-v1 classify-rung-L2-vtie; do
  g r17_gate_b v20 v20-$c 0.8 2 7200 -- python3 $S/zk60_native_rg_classgate.py --bundle $C/$c --evidence $P/v20 --name v20-$c
done
date -u > $P/r17_gate_b.finished
