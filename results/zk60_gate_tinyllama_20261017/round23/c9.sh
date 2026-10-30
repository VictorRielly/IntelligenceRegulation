#!/bin/bash
# PRIVACY GATE lane, gate round 23: condition C-9 of the re-review of draft v2 -- TS-1, the review controls and the
# claim census on ONE real R13 block (block 0 = stage-01 of the hate-values capture), with the round-22 v2 wrapper
# (`--block-stages 1 --skip-classifier`). Single-threaded Python, the block's three roles peaked 0.85 GiB in round 22
# (memory-mapped store, lazy), so per the coordinator (02:1x UTC) it runs in the LIGHT class, need 1.0 / cap 1.5,
# --max-secs 7200, beside other lanes' jobs, never holding the heavy lock. No checkpoint stream. Marker c9.done.
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017
cd /tmp
python3 $E/round20/alone_check.py gate23- > $E/round23/c9.box_at_launch.json
date -u > $E/round23/c9.launched
python3 /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py run --class light --need-gib 1.0 --cap-gib 1.5 \
  --label gate23-c9-real-block0-ts1 --wait-secs 3600 --max-secs 7200 --log $E/round23/logs/c9-real-block0.log \
  --done $E/round23/logs/c9-real-block0.guard.done --result-json $E/round23/logs/c9-real-block0.guard.json -- \
  /usr/bin/env OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 python3 -B \
  /home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/r22-item3/zk60_r22_classts2.py \
  --bundle /home/victor/zk60-artifacts/token-io/captures/classify-r13-shield-t128-cli-hate-r17-values \
  --evidence $E/round23 --name c9-real-block0-ts1-census --block-stages 1 --skip-classifier
echo $? > $E/round23/c9.done
date -u > $E/round23/c9.finished
