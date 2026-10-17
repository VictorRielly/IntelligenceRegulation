#!/bin/bash
# D24 review ROUND 4: export-side memory amplification, measured under the cap
set -u
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
R=/home/victor/IntelligenceRegulation/results/zk60_d24_review_20261017/r4
K=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-review-r4-scratch/review_out/stack2
ID=$(cat $K/identity.hex)
for pair in "r4-exp-fat40:$R/zk60_trained_block.review-r4.release.bin" "r4-exp-fat40-r4cli:/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r4/zk60_trained_block.release.bin"; do
  label=${pair%%:*}; bin=${pair#*:}
  python3 $G run --class light --need-gib 1 --cap-gib 1.5 --label $label --wait-secs 14400 --max-secs 60 \
    --log $R/$label.log --done $R/$label.done --result-json $R/$label.guard.json -- \
    /usr/bin/time -v $bin stack-verify --export $K/exp-fat40 --expect-statement $ID --artifact $K/run
  echo "[$(date -u +%H:%M:%SZ)] $label exit $?" >> $R/fat40.out
done
echo done > $R/r4_fat40.done
