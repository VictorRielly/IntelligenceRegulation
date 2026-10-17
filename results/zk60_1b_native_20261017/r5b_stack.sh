#!/bin/bash
# NATIVE LANE R5b: one stack run with the R5b CLI (CPU), HL_PB_TIMING=1,
# RAYON_NUM_THREADS=16, no in-process verify (the prover's statement goes to
# <run>.unverified-statement/), then a FRESH-process verify with every
# run-level control from the VERIFIER'S COPY of the export (no seq_*; privacy
# review P-5), which promotes the statement to <run>/statement/ (P-1, M-9).
# The budget is pre-checked OUTSIDE the heavy lock (the guard holds its locks
# while it waits for admission).
# usage: r5b_stack.sh <export dir> <seq id> <need> <cap> [witness-cache-gib]
set -u
D=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
X=$D/r5b/zk60_trained_block.release.bin
E=$1; S=$2; NEED=$3; CAP=$4; WC=${5:-4}
V=$(basename "$E"); R=$D/r5b/stack-$V-$S-cpu
VE=$D/r5b/verifier-exports/$V
[ -d "$VE" ] || { echo "no verifier copy $VE"; exit 1; }
mkdir -p "$R"
pre() {  # $1 = need
  until out=$(python3 $G check --class cpu --need-gib $1 2>&1); echo "$out" | grep -q "OK to start now" || ! echo "$out" | sed 's/[^;]*is held//g' | grep -q "budget\|MemAvailable"; do sleep 30; done
}
pre $NEED
python3 $G run --class cpu --need-gib $NEED --cap-gib $CAP --label r5b-stack-$V --wait-secs 14400 --max-secs 5400 \
  --log "$R/prove.log" --done "$R/prove.done" --result-json "$R/prove.guard.json" \
  -- /usr/bin/env HL_PB_TIMING=1 RAYON_NUM_THREADS=16 $X stack-prove --export "$E" --seq "$S" --out "$R/run" --witness-cache-gib $WC
rc=$?
[ $rc -eq 0 ] || { echo "stack-prove $V exit $rc"; exit $rc; }
ID=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['trained_statement_identity'])" "$R/run.unverified-statement/statement.json")
pre ${VNEED:-2.5}
python3 $G run --class cpu --need-gib ${VNEED:-2.5} --cap-gib ${VCAP:-8} --label r5b-stack-verify-$V --wait-secs 14400 --max-secs 5400 \
  --log "$R/verify.log" --done "$R/verify.done" --result-json "$R/verify.guard.json" \
  -- /usr/bin/env RAYON_NUM_THREADS=16 $X stack-verify --export "$VE" --artifact "$R/run" --expect-statement "$ID" --controls
echo "stack-verify $V exit $?"
