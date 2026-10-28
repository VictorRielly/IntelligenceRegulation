#!/bin/bash
# PRIVACY GATE lane, gate round 7: the token gate at tools v9 -- run from the
# FROZEN v9 snapshot, since the working copy is already v10 work -- on the
# Llama-3-8B T32 token captures at L = 1 (dense ho00, fixed BOS).  Guarded
# LIGHT jobs, one at a time; captures read in place.
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017
P=$E/token_io
V9=/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/frozen_v9
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
C=/home/victor/zk60-artifacts/token-io/captures
python3 $E/v4/freeze.py check $E/gate-tinyllama.tools.frozen.v9.sha256 $V9 > $P/token_queue_8b2_v9.toolcheck 2>&1 || { echo "TOOLS MOVED" > $P/token_queue_8b2_v9.finished; exit 4; }
mkdir -p $P/r7c
cd /tmp
for b in L2-dense L2-fixed; do
  n=token-r7c-8b-$b
  python3 $G run --class light --need-gib 3 --cap-gib 5 --label gate-$n --wait-secs 21600 --max-secs 7200 \
    --log $P/r7c/$n.log --done $P/r7c/$n.done --result-json $P/r7c/$n.guard.json -- \
    python3 $V9/scripts/zk60_native_rg_tokengate.py --bundle $C/llama3-8b-t32-$b-pt1 --evidence $P/r7c --name $n
  rc=$?; echo "$(date -u +%H:%M:%S) $n exit $rc" >> $P/token_queue_8b2_v9.progress
done
date -u > $P/token_queue_8b2_v9.finished
