#!/bin/bash
# NATIVE LANE round 2 runner (2026-10-17). usage: r2_run.sh <export dir> <layer> <seq id> [--controls]
# Proves ONE trained block as a bound one-block run with the round-2 release
# CLI (guarded cpu job), then verifies it in a FRESH process (guarded cpu
# job). Evidence: results/zk60_1b_native_20261017/r2/<variant>-L<layer>-<seq>/
set -u
D=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
X=$D/r2/zk60_trained_block.release.bin
E=$1; L=$2; S=$3; shift 3
V=$(basename "$E"); R=$D/r2/$V-L$L-$S
mkdir -p "$R"
python3 $G run --class cpu --need-gib 3 --cap-gib 5 --label r2-prove-$V-L$L-$S --wait-secs 14400 --max-secs 3600 \
  --log "$R/prove.log" --done "$R/prove.done" --result-json "$R/prove.guard.json" \
  -- $X prove --export "$E" --layer "$L" --seq "$S" --out "$R/artifact" "$@"
rc=$?
[ $rc -eq 0 ] || { echo "prove exit $rc"; exit $rc; }
ID=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['trained_statement_identity'])" "$R/artifact/statement.json")
python3 $G run --class cpu --need-gib 2 --cap-gib 4 --label r2-verify-$V-L$L-$S --wait-secs 14400 --max-secs 1800 \
  --log "$R/verify.log" --done "$R/verify.done" --result-json "$R/verify.guard.json" \
  -- $X verify --export "$E" --layer "$L" --artifact "$R/artifact" --expect-statement "$ID" "$@"
echo "verify exit $?"
