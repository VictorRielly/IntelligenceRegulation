#!/bin/bash
# gate round 12, queue A: the token gate (tools v16) on the two L = 22
# re-captures.  Measured (round 7, v10): 3,429-3,756 s, 1.75 GiB.
. /home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017/round12/r12_common.sh
python3 $E/v4/freeze.py check $E/gate-tinyllama.tools.frozen.v16.sha256 $GT/frozen_v16 > $P/r12_gate_a.toolcheck 2>&1 || exit 4
cd /tmp
for c in tinyllama-t32-L22-dense-pt1 tinyllama-t32-L22-fixed-pt1; do
  wb $c || { echo "no capture $c" >> $P/r12_gate_a.progress; continue; }
  g r12_gate_a gate r9-tokengate-$c 2.2 3 7200 -- python3 $S/zk60_native_rg_tokengate.py --bundle $C/$c --evidence $P/gate --name r9-tokengate-$c
done
date -u > $P/r12_gate_a.finished
