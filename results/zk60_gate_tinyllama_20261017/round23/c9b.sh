#!/bin/bash
# PRIVACY GATE lane, gate round 23, condition C-9, ATTEMPT 3 (written 2026-10-30 ~07:10 UTC). Attempt 1 (02:15) died
# in the laptop crash; attempt 2 (`c9.sh`, relaunched unchanged 05:27:55) ran into its --max-secs 7200 after the three
# role analyses, the census and TS-1 on A and H (TS-1 rows at the real block cost 2,584 s and 551 s; Input's has 16x
# H's data generators). This is the SAME command with the SAME unmodified v2 wrapper, the same class / need / cap and
# the same inputs; only --max-secs is sized to the job (the re-review's note N22-1: "--max-secs sized to the slot it is
# given") and the output names differ (c9b-*) so the two runs never share a file. Single-threaded Python, ~0.35 GiB,
# LIGHT need 1.0 / cap 1.5, beside other lanes' jobs, never holding the heavy lock. No checkpoint stream. Marker
# c9b.done.
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017
cd /tmp
while [ -e $E/HOLD ]; do sleep 30; done
python3 $E/round20/alone_check.py gate23- > $E/round23/c9b.box_at_launch.json
date -u > $E/round23/c9b.launched
python3 /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py run --class light --need-gib 1.0 --cap-gib 1.5 \
  --label gate23-c9b-real-block0-ts1 --wait-secs 3600 --max-secs 25200 --log $E/round23/logs/c9b-real-block0.log \
  --done $E/round23/logs/c9b-real-block0.guard.done --result-json $E/round23/logs/c9b-real-block0.guard.json -- \
  /usr/bin/env OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 python3 -B \
  /home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/r22-item3/zk60_r22_classts2.py \
  --bundle /home/victor/zk60-artifacts/token-io/captures/classify-r13-shield-t128-cli-hate-r17-values \
  --evidence $E/round23 --name c9b-real-block0-ts1-census --block-stages 1 --skip-classifier
echo $? > $E/round23/c9b.done
date -u > $E/round23/c9b.finished
