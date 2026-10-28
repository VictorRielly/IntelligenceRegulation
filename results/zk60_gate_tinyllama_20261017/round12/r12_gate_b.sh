#!/bin/bash
# gate round 12, queue B: the token gate (tools v16) on the TinyLlama L = 1, 2
# and 8B L = 1, 2 re-captures.  Measured (round 7, v10): TinyLlama 653-862 s,
# 0.55-0.60 GiB; 8B 689-942 s, 0.89-0.96 GiB.
. /home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017/round12/r12_common.sh
python3 $E/v4/freeze.py check $E/gate-tinyllama.tools.frozen.v16.sha256 $GT/frozen_v16 > $P/r12_gate_b.toolcheck 2>&1 || exit 4
cd /tmp
for c in tinyllama-t32-L1-dense-pt1 tinyllama-t32-L1-fixed-pt1 tinyllama-t32-L2-dense-pt1 tinyllama-t32-L2-fixed-pt1 llama3-8b-t32-L1-dense-pt1 llama3-8b-t32-L1-fixed-pt1 llama3-8b-t32-L2-dense-pt1 llama3-8b-t32-L2-fixed-pt1; do
  wb $c || { echo "no capture $c" >> $P/r12_gate_b.progress; continue; }
  case $c in llama3*) n=1.3; k=2.5;; *) n=1; k=2;; esac
  g r12_gate_b gate r9-tokengate-$c $n $k 3600 -- python3 $S/zk60_native_rg_tokengate.py --bundle $C/$c --evidence $P/gate --name r9-tokengate-$c
done
date -u > $P/r12_gate_b.finished
