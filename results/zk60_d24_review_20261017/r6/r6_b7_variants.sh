#!/bin/bash
# round 6: the digest pass of my CLI over the two b7 variants (zero pin: the
# identity is printed, or the door refuses). Each leaf guarded.
set -u
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
R=/home/victor/IntelligenceRegulation/results/zk60_d24_review_20261017/r6
S=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-review-r6-scratch
X=$R/zk60_trained_block.review-r6.release.bin
ZERO=0000000000000000000000000000000000000000000000000000000000000000
ART=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r6/stack-llama3_8b_pg_rot1_b7_T128-ho00-cpu/run
for v in flat shs9; do
  python3 $G run --class cpu --need-gib 3 --cap-gib 5 --label r6-8b-b7-$v --wait-secs 14400 --max-secs 600 \
    --log $R/r6-8b-b7-$v.log --done $R/r6-8b-b7-$v.done --result-json $R/r6-8b-b7-$v.guard.json \
    -- /usr/bin/env RAYON_NUM_THREADS=16 $X stack-verify --export $S/verifier-8b-b7-T128-$v --artifact $ART --expect-statement $ZERO
  echo "[$(date -u +%H:%M:%SZ)] r6-8b-b7-$v exit $?" >> $R/queue.out
done
echo done > $R/r6_b7_variants.done
