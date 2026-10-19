#!/bin/bash
# G-7 sub-lane: the terminal-surjection computation (ts_trained.py) on the
# gate's R5b trained captures, one guarded LIGHT job (single-threaded Python).
# Not a privacy result.
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017/g7
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
A=/home/victor/zk60-artifacts
cd /tmp
mkdir -p $E/ts
echo "$(date -u +%FT%TZ) ts queue start" >> $E/ts_queue.progress
python3 $G run --class light --need-gib 1.5 --cap-gib 3 --label g7-ts --wait-secs 14400 --max-secs 5400 \
  --log $E/ts/g7-ts.log --done $E/ts/g7-ts.done --result-json $E/ts/g7-ts.guard.json -- \
  python3 $E/ts_trained.py --out $E/ts \
  --bundle $A/tinyllama-trained-r5b-capture-dense-l1 \
  --bundle $A/tinyllama-trained-r5b-capture-zero-l1 \
  --bundle $A/tinyllama-trained-r5b-capture-dense-l2
rc=$?
echo "$(date -u +%FT%TZ) g7-ts exit $rc" >> $E/ts_queue.progress
exit $rc
