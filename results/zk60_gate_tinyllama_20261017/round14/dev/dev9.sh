#!/bin/bash
cd /tmp
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
for n in l2-dense l1-dense; do
  o=$( [ $n = l2-dense ] && echo l2-zero || echo l1-zero )
  python3 $G run --class light --need-gib 1.5 --cap-gib 3 --label gate-dev9-$n --wait-secs 3600 --max-secs 1800 --log /home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017/round14/dev/dev9-$n.log --done /home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017/round14/dev/dev9-$n.done --result-json /home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017/round14/dev/dev9-$n.guard.json -- python3 /home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/scripts/zk60_native_rg_m125.py --bundle /home/victor/zk60-artifacts/dd-gate-r9/tl128dd-$n --other /home/victor/zk60-artifacts/dd-gate-r9/tl128dd-$o --evidence /home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017/round14/dev --name dev9-tl128dd-$n-a --stages load,replay,hash,terminals,commitments,boundary,preimage,export,channels --export /home/victor/IntelligenceRegulation/results/zk60_fidelity_parity_20261019/exports/tinyllama_dg_rot1_T128
done
