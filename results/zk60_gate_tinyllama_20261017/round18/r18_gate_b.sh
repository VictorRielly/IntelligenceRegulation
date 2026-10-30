#!/bin/bash
# PRIVACY GATE lane, gate round 18, queue B: frozen tools v21 on the L2 R-C2 /
# R-C3 classifier captures (v0 / v1 / vtie, the short item at v1, chunk 1 of
# the 27-id item). Declarations from round 17's measured peaks plus a margin.
. /home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017/round18/r18_common.sh
cd /tmp
python3 $E/v4/freeze.py check $E/gate-tinyllama.tools.frozen.v21.sha256 $GT/frozen_v21 > $P/r18_gate_b.toolcheck 2>&1 || { echo "TOOLS MOVED" > $P/r18_gate_b.finished; exit 4; }
for c in classify-rc3-rung-L2-v0 classify-rc3-rung-L2-v1 classify-rc3-rung-L2-vtie classify-rc3-rung-L2-v1-short20 classify-rc3-rung-L2-v1-chunk1o27; do
  g r18_gate_b v21 v21-$c 0.8 2 7200 -- python3 $S/zk60_native_rg_classgate.py --bundle $C/$c --evidence $P/v21 --name v21-$c
done
date -u > $P/r18_gate_b.finished
