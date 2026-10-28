#!/bin/bash
# PRIVACY GATE lane, gate round 7: the token gate (tools v9) on the step-B
# L = 22 captures (R2 TinyLlama T32, public row, mode i; dense ho00 and fixed
# 32 x BOS).  Guarded LIGHT jobs, one at a time; captures read in place.
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017
P=$E/token_io
GT=/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
C=/home/victor/zk60-artifacts/token-io/captures
python3 $E/v4/freeze.py check $E/gate-tinyllama.tools.frozen.v9.sha256 $GT > $P/token_queue_l22.toolcheck 2>&1 || { echo "TOOLS MOVED" > $P/token_queue_l22.finished; exit 4; }
mkdir -p $P/r7c
cd /tmp
for b in L22-dense L22-fixed; do
  n=token-r7c-$b
  python3 $G run --class light --need-gib 6 --cap-gib 7.5 --label gate-$n --wait-secs 21600 --max-secs 10800 \
    --log $P/r7c/$n.log --done $P/r7c/$n.done --result-json $P/r7c/$n.guard.json -- \
    python3 $GT/scripts/zk60_native_rg_tokengate.py --bundle $C/tinyllama-t32-$b-pt1 --evidence $P/r7c --name $n
  rc=$?; echo "$(date -u +%H:%M:%S) $n exit $rc" >> $P/token_queue_l22.progress
done
date -u > $P/token_queue_l22.finished
