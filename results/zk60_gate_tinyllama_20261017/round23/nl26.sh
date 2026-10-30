#!/bin/bash
# PRIVACY GATE lane, gate round 23, re-review note N-1: NL-1 S1-S5 (T-0 / E-0, S1, S4 in four challenge modes, S3, S5)
# on the 7 R13-changed slots of ALL 26 real blocks of the hate-values capture (round 22 ran blocks 0 and 2), with the
# round-22 script (`--parts r13 --lazy-store --no-b3 --skip-classifier-t0`): this covers G = 20 at the real shape too.
# ~1.6 GiB in round 22 (2 blocks) -> cpu 2.5 / 3.5, max 3600 s. Takes turns: waits until no other lane's guarded job
# is live or waiting (token round 18 / Sol first), twice 60 s apart. No checkpoint stream. Marker nl26.done.
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017
W=/home/victor/IntelligenceRegulation/results/zk60_guard_fix_20261021/WINDOW_HOLD
A=$E/round20/alone_check.py
cd /tmp
while true; do
  while [ -e $W ] || [ -e $E/HOLD ]; do sleep 30; done
  if python3 $A gate23- > $E/round23/nl26.alone.last; then
    sleep 60
    if python3 $A gate23- > $E/round23/nl26.alone.last; then break; fi
  fi
  sleep 30
done
cp $E/round23/nl26.alone.last $E/round23/nl26.alone_at_launch.json
date -u > $E/round23/nl26.launched
python3 /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py run --class cpu --need-gib 2.5 --cap-gib 3.5 \
  --label gate23-nl1-real-all26 --wait-secs 7200 --max-secs 3600 --log $E/round23/logs/nl26.log \
  --done $E/round23/logs/nl26.guard.done --result-json $E/round23/logs/nl26.guard.json -- \
  /usr/bin/env OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 python3 -B \
  /home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/r22-item3/zk60_r22_classnl.py \
  --bundle /home/victor/zk60-artifacts/token-io/captures/classify-r13-shield-t128-cli-hate-r17-values \
  --evidence $E/round23 --name nl-real-hate-all26 --parts r13 --lazy-store --no-b3 --skip-classifier-t0
echo $? > $E/round23/nl26.done
date -u > $E/round23/nl26.finished
