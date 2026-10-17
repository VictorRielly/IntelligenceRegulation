#!/bin/bash
# NATIVE LANE round 3, R3-3 (2026-10-17): the 22-block pg_rot1_b4 stack at
# T32, T64, T128 on the CPU (RAYON_NUM_THREADS=16), each verified in a FRESH
# process with every run-level control; then the boundary-lie control on a
# three-block T128 stack. usage: r3_ladder_cpu.sh <seq id>
set -u
D=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
X=$D/r3/zk60_trained_block.release.bin
EX=/home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929/export
S=$1
N=16
for V in pg_rot1_b4_T32_cal128:4:7 pg_rot1_b4_T64_cal128:4:8 pg_rot1_b4_T128:6:10; do
  E=$EX/${V%%:*}; rest=${V#*:}; NEED=${rest%%:*}; CAP=${rest#*:}
  R=$D/r3/stack-$(basename $E)-$S-cpu
  mkdir -p "$R"
  python3 $G run --class cpu --need-gib $NEED --cap-gib $CAP --label r3-stack-cpu-$(basename $E) --wait-secs 14400 --max-secs 5400 \
    --log "$R/prove.log" --done "$R/prove.done" --result-json "$R/prove.guard.json" \
    -- /usr/bin/env RAYON_NUM_THREADS=$N $X stack-prove --export "$E" --seq "$S" --out "$R/run"
  rc=$?
  if [ $rc -ne 0 ]; then echo "stack-prove $(basename $E) exit $rc"; continue; fi
  ID=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['trained_statement_identity'])" "$R/run/statement/statement.json")
  python3 $G run --class cpu --need-gib 4 --cap-gib 7 --label r3-stack-verify-$(basename $E) --wait-secs 14400 --max-secs 3600 \
    --log "$R/verify.log" --done "$R/verify.done" --result-json "$R/verify.guard.json" \
    -- /usr/bin/env RAYON_NUM_THREADS=$N $X stack-verify --export "$E" --artifact "$R/run" --expect-statement "$ID" --controls
  echo "stack-verify $(basename $E) exit $?"
done
L=$D/r3/stack-pg_rot1_b4_T128-$S-lie
mkdir -p "$L"
python3 $G run --class cpu --need-gib 5 --cap-gib 8 --label r3-stack-lie-T128 --wait-secs 14400 --max-secs 3600 \
  --log "$L/prove.log" --done "$L/prove.done" --result-json "$L/prove.guard.json" \
  -- /usr/bin/env RAYON_NUM_THREADS=$N $X stack-prove --export "$EX/pg_rot1_b4_T128" --seq "$S" --out "$L/run" --layers 0..3 --lie-at-boundary 1
echo "lie control exit $?"
