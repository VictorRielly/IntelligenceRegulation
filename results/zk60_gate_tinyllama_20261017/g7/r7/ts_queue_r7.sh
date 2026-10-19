#!/bin/bash
# G-7 follow-up (review round 2, Q-5): the same terminal-surjection computation
# (g7/ts_trained.py, unchanged, sha256 d6f6cf93...) on the R7 captures: the
# three harness bundles and the CLI-path bundle.  One guarded LIGHT job.
# Not a privacy result.
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017/g7
R=$E/r7
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
A=/home/victor/zk60-artifacts
cd /tmp
echo "$(date -u +%FT%TZ) ts r7 queue start" >> $R/ts_queue_r7.progress
python3 $G run --class light --need-gib 1.5 --cap-gib 3 --label g7-ts-r7 --wait-secs 14400 --max-secs 7200 \
  --log $R/g7-ts-r7.log --done $R/g7-ts-r7.done --result-json $R/g7-ts-r7.guard.json -- \
  python3 $E/ts_trained.py --out $R \
  --bundle $A/tinyllama-trained-r7-capture-dense-l1 \
  --bundle $A/tinyllama-trained-r7-capture-zero-l1 \
  --bundle $A/tinyllama-trained-r7-capture-dense-l2 \
  --bundle $A/tinyllama-cli-r7-capture-dense-l2
rc=$?
echo "$(date -u +%FT%TZ) g7-ts-r7 exit $rc" >> $R/ts_queue_r7.progress
exit $rc
