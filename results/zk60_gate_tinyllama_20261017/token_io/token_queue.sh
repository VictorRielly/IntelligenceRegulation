#!/bin/bash
# PRIVACY GATE lane, gate round 7: the token gate (tools v9) on the four step-A
# captures (R2 TinyLlama T32, public row, mode i; L = 1 and 2, dense ho00 and
# fixed 32 x BOS).  Guarded LIGHT jobs, one at a time; captures read in place.
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017
P=$E/token_io
GT=/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
C=/home/victor/zk60-artifacts/token-io/captures
python3 $E/v4/freeze.py check $E/gate-tinyllama.tools.frozen.v9.sha256 $GT > $P/token_queue.toolcheck 2>&1 || { echo "TOOLS MOVED" > $P/token_queue.finished; exit 4; }
python3 -m unittest discover -s $GT/tests > $P/v9-unittests.log 2>&1
rc=$?; echo "$(date -u +%H:%M:%S) unittests exit $rc" >> $P/token_queue.progress
mkdir -p $P/r7c
cd /tmp
for b in L1-dense L1-fixed L2-dense L2-fixed; do
  n=token-r7c-$b
  python3 $G run --class light --need-gib 1.5 --cap-gib 3 --label gate-$n --wait-secs 21600 --max-secs 3600 \
    --log $P/r7c/$n.log --done $P/r7c/$n.done --result-json $P/r7c/$n.guard.json -- \
    python3 $GT/scripts/zk60_native_rg_tokengate.py --bundle $C/tinyllama-t32-$b-pt1 --evidence $P/r7c --name $n
  rc=$?; echo "$(date -u +%H:%M:%S) $n exit $rc" >> $P/token_queue.progress
done
date -u > $P/token_queue.finished
