#!/bin/bash
# NATIVE LANE round 2, R2-3 (2026-10-17): ALL 22 pg_rot1 blocks as ONE bound
# run (CPU), then a FRESH-process verify of the run directory with every
# run-level control, then the prover-side boundary-lie control on a short
# stack. usage: r2_stack.sh <seq id>
set -u
D=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
X=$D/r2/zk60_trained_block.release.bin
E=/home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929/export/pg_rot1_export_T32
S=$1
R=$D/r2/stack-pg_rot1-$S-cpu
mkdir -p "$R"
python3 $G run --class cpu --need-gib 4 --cap-gib 7 --label r2-stack-prove-$S --wait-secs 14400 --max-secs 5400 \
  --log "$R/prove.log" --done "$R/prove.done" --result-json "$R/prove.guard.json" \
  -- $X stack-prove --export "$E" --seq "$S" --out "$R/run"
rc=$?
[ $rc -eq 0 ] || { echo "stack-prove exit $rc"; exit $rc; }
ID=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['trained_statement_identity'])" "$R/run/statement/statement.json")
python3 $G run --class cpu --need-gib 4 --cap-gib 7 --label r2-stack-verify-$S --wait-secs 14400 --max-secs 3600 \
  --log "$R/verify.log" --done "$R/verify.done" --result-json "$R/verify.guard.json" \
  -- $X stack-verify --export "$E" --artifact "$R/run" --expect-statement "$ID" --controls
echo "stack-verify exit $?"
L=$D/r2/stack-pg_rot1-$S-lie
mkdir -p "$L"
python3 $G run --class cpu --need-gib 3 --cap-gib 5 --label r2-stack-lie-$S --wait-secs 14400 --max-secs 3600 \
  --log "$L/prove.log" --done "$L/prove.done" --result-json "$L/prove.guard.json" \
  -- $X stack-prove --export "$E" --seq "$S" --out "$L/run" --layers 0..3 --lie-at-boundary 1
echo "lie control exit $?"
