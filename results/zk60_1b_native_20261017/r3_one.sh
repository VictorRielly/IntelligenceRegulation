#!/bin/bash
# NATIVE LANE round 3: one block, prove (+ fresh verify) with a given CLI and
# an explicit rayon thread count. usage: r3_one.sh <tag> <binary> <export> <layer> <seq> <threads> [extra prove flags]
set -u
D=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
TAG=$1; X=$2; E=$3; L=$4; S=$5; N=$6; shift 6
V=$(basename "$E"); R=$D/r3/one-$TAG-$V-L$L-$S
mkdir -p "$R"
python3 $G run --class cpu --need-gib ${NEED:-3} --cap-gib ${CAP:-6} --label r3-one-$TAG-$V-L$L --wait-secs 14400 --max-secs 3600 \
  --log "$R/prove.log" --done "$R/prove.done" --result-json "$R/prove.guard.json" \
  -- /usr/bin/env RAYON_NUM_THREADS=$N $X prove --export "$E" --layer "$L" --seq "$S" --out "$R/artifact" "$@"
rc=$?
[ $rc -eq 0 ] || { echo "prove exit $rc"; exit $rc; }
ID=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['trained_statement_identity'])" "$R/artifact/statement.json")
python3 $G run --class cpu --need-gib 2 --cap-gib 4 --label r3-one-verify-$TAG-$V-L$L --wait-secs 14400 --max-secs 1800 \
  --log "$R/verify.log" --done "$R/verify.done" --result-json "$R/verify.guard.json" \
  -- /usr/bin/env RAYON_NUM_THREADS=$N $X verify --export "$E" --layer "$L" --artifact "$R/artifact" --expect-statement "$ID"
echo "verify exit $?"
