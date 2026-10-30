#!/bin/bash
# PRIVACY GATE lane, gate round 19, queue B (frozen tools v22): the R13-rung short items (n = 1, 11 at v0 / v1 / tie;
# n = 22 at v1). Light class, need 1.3 / cap 2.0.
. /home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017/round19/r19_common.sh
cd /tmp
python3 $E/v4/freeze.py check $E/gate-tinyllama.tools.frozen.v22.sha256 $GT/frozen_v22 > $P/r19_gate_b.toolcheck 2>&1 || { echo "TOOLS MOVED" > $P/r19_gate_b.finished; exit 4; }
for c in classify-r13-rung-L2-v0-short1 classify-r13-rung-L2-v1-short1 classify-r13-rung-L2-vtie-short1 classify-r13-rung-L2-v0-short11 classify-r13-rung-L2-v1-short11 classify-r13-rung-L2-vtie-short11 classify-r13-rung-L2-v1-short22; do
  g r19_gate_b v22 v22-$c light 1.3 2.0 7200 -- python3 -B $S/zk60_native_rg_classgate.py --bundle $C/$c --evidence $P/v22 --name v22-$c --calibration-export $R13FX
done
date -u > $P/r19_gate_b.finished
