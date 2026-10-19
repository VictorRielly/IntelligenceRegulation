#!/bin/bash
# round 6 re-check (2026-10-19): the native lane's b7 T128 stack, fresh
# process, my CLI, my verifier copy of the calibration lane's export, with
# --controls; read only (its statement/ exists, so stack-verify only checks it)
set -u
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
R=/home/victor/IntelligenceRegulation/results/zk60_d24_review_20261017/r6
X=$R/zk60_trained_block.review-r6.release.bin
V=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-review-r6-scratch/verifier-8b-b7-T128
ART=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r6/stack-llama3_8b_pg_rot1_b7_T128-ho00-cpu/run
ID=97c4acda9da994c11790c2c8ec93b44beecb21501686b7e25965d2c18f970566
python3 $G run --class cpu --need-gib 3 --cap-gib 5 --label r6-8b-b7-stack-verify --wait-secs 14400 --max-secs 1800 \
  --log $R/r6-8b-b7-stack-verify.log --done $R/r6-8b-b7-stack-verify.done --result-json $R/r6-8b-b7-stack-verify.guard.json \
  -- /usr/bin/env RAYON_NUM_THREADS=16 /usr/bin/time -v $X stack-verify --export $V --artifact $ART --expect-statement $ID --controls
echo "[$(date -u +%H:%M:%SZ)] r6-8b-b7-stack-verify exit $(cat $R/r6-8b-b7-stack-verify.done)" >> $R/queue.out
echo done > $R/r6_b7_stack_verify.done
