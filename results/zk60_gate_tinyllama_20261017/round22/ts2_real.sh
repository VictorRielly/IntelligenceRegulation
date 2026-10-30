#!/bin/bash
# gate round 22: TS-1 + a written record of the terminal surjection at the REAL classifier stages (IN-C, OUT-C) of the
# hate-values capture, with the fork's v2 wrapper (cheapest TS-1 group, incremental records; dev-run on the rung).
# Launched by the parent after Astra's three categories and the GR4 chain, the box alone. cpu 1.0 / 2.0 (the real
# roles' analysis peaked 0.11 GiB; the rung TS-1 0.34), max 1500 s. Marker ts2_real.done.
cd /tmp
python3 /home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017/round20/alone_check.py gate22- > /home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017/round22/ts2_real.alone_at_launch.json
python3 /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py run --class cpu --need-gib 1.0 --cap-gib 2.0   --label gate22-ts2-real-classifier --wait-secs 1800 --max-secs 1500 --log /home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017/round22/item3/logs/ts2-real-classifier.log   --done /home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017/round22/item3/logs/ts2-real-classifier.guard.done --result-json /home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017/round22/item3/logs/ts2-real-classifier.guard.json --   /usr/bin/env OPENBLAS_NUM_THREADS=1 python3 -B /home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/r22-item3/zk60_r22_classts2.py   --bundle /home/victor/zk60-artifacts/token-io/captures/classify-r13-shield-t128-cli-hate-r17-values   --evidence /home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017/round22/item3 --name ts2-real-hate-classifier-stages
echo $? > /home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017/round22/ts2_real.done
