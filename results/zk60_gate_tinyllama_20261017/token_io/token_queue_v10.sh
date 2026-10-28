#!/bin/bash
# PRIVACY GATE lane, gate round 7 step 2: the token gate at tools v10 (the
# computed word-level joint, the new slots' terminal identity and NL-1, the
# block-stage terminal identity inside the token run, the full preimage on
# every commitment and the joint assignment, the P family on IN / OUT) on
# L = 1, 2 and 22, dense and fixed.  Guarded LIGHT jobs, one at a time.
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017
P=$E/token_io
GT=/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
C=/home/victor/zk60-artifacts/token-io/captures
python3 $E/v4/freeze.py check $E/gate-tinyllama.tools.frozen.v10.sha256 $GT > $P/token_queue_v10.toolcheck 2>&1 || { echo "TOOLS MOVED" > $P/token_queue_v10.finished; exit 4; }
python3 -m unittest discover -s $GT/tests > $P/v10-unittests.log 2>&1
rc=$?; echo "$(date -u +%H:%M:%S) unittests exit $rc" >> $P/token_queue_v10.progress
mkdir -p $P/v10
cd /tmp
run() {  # run <capture dir name> <need> <cap> <max>
  local b=$1 n=token-v10-$1
  python3 $G run --class light --need-gib $2 --cap-gib $3 --label gate-$n --wait-secs 21600 --max-secs $4 \
    --log $P/v10/$n.log --done $P/v10/$n.done --result-json $P/v10/$n.guard.json -- \
    python3 $GT/scripts/zk60_native_rg_tokengate.py --bundle $C/$b --evidence $P/v10 --name $n
  local rc=$?; echo "$(date -u +%H:%M:%S) $n exit $rc" >> $P/token_queue_v10.progress
}
run tinyllama-t32-L1-dense-pt1 2 3.5 5400
run tinyllama-t32-L1-fixed-pt1 2 3.5 5400
run tinyllama-t32-L2-dense-pt1 2.5 4 7200
run tinyllama-t32-L2-fixed-pt1 2.5 4 7200
run tinyllama-t32-L22-dense-pt1 6.5 8 21600
run tinyllama-t32-L22-fixed-pt1 6.5 8 21600
run llama3-8b-t32-L1-dense-pt1 4 6 10800
run llama3-8b-t32-L1-fixed-pt1 4 6 10800
run llama3-8b-t32-L2-dense-pt1 4.5 6.5 14400
run llama3-8b-t32-L2-fixed-pt1 4.5 6.5 14400
date -u > $P/token_queue_v10.finished
