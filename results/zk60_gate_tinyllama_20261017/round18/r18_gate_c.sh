#!/bin/bash
# PRIVACY GATE lane, gate round 18, queue C (REVIEW_R14 §10 item 4, coordinator ~03:05): frozen tools
# v21 on the n sweep (L2 x v0 / v1 / vtie at n = 1, 11, 22), then on the CLI-path capture of a short
# item (n = 11, gate patch H18-1) once it exists. Declarations as queues A / B.
. /home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017/round18/r18_common.sh
cd /tmp
python3 $E/v4/freeze.py check $E/gate-tinyllama.tools.frozen.v21.sha256 $GT/frozen_v21 > $P/r18_gate_c.toolcheck 2>&1 || { echo "TOOLS MOVED" > $P/r18_gate_c.finished; exit 4; }
for n in 1 11 22; do for v in v0 v1 vtie; do
  c=classify-rc3-rung-L2-$v-short$n
  g r18_gate_c v21 v21-$c 0.8 2 7200 -- python3 $S/zk60_native_rg_classgate.py --bundle $C/$c --evidence $P/v21 --name v21-$c
done; done
until [ -f $P/cap/r18_cli_short.done ]; do sleep 30; done
if [ "$(cat $P/cap/r18_cli_short.done)" = "0" ]; then
  c=classify-rc3-cli-short11-r14
  g r18_gate_c v21 v21-$c 0.8 2 7200 -- python3 $S/zk60_native_rg_classgate.py --bundle $C/$c --evidence $P/v21 --name v21-$c
fi
date -u > $P/r18_gate_c.finished
