#!/bin/bash
# GPU ZERO-CHECK lane: FRESH-process CPU verify of one stack run directory
# with the FROZEN review-r3 CPU binary (built from the unchanged verifier
# sources; the lane changed prover arithmetic only), expecting the CPU
# run's statement identity at TinyLlama T128 ho00 (r3/r4 CPU and GPU runs:
# 53a5667d...). The run's own statement.json must carry the same identity.
# usage: verify.sh <tag>
set -u
D=/home/victor/IntelligenceRegulation/results/zk60_gpu_zerocheck_20261017
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
X=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r3/zk60_trained_block.release.bin
E=${EXPORT:-/home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929/export/pg_rot1_b4_T128}
CPU_ID=53a5667decccbe4d0d9b9bc31b661339cf6b7c1b470cf9197a88b1cb5711534d
TAG=$1
R=$D/stack-$TAG
ID=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['trained_statement_identity'])" "$R/run/statement/statement.json")
if [ "$ID" != "$CPU_ID" ]; then echo "statement identity $ID differs from the CPU run's $CPU_ID"; exit 3; fi
python3 $G run --class cpu --need-gib ${VNEED:-2} --cap-gib ${VCAP:-4} --label "gzc-verify-$TAG" --wait-secs 14400 --max-secs 1800 \
  --log "$R/verify.log" --done "$R/verify.done" --result-json "$R/verify.guard.json" \
  -- /usr/bin/env RAYON_NUM_THREADS=16 $X stack-verify --export "$E" --artifact "$R/run" --expect-statement "$CPU_ID"
echo "verify $TAG exit $?"
