#!/bin/bash
# NATIVE LANE T5 runner (2026-10-17). usage: t5_run.sh <export variant dir> <layer> <seq id> [extra prove flags]
# Proves ONE trained block with the saved release CLI (guarded cpu job), then
# verifies it in a FRESH process with every control (guarded cpu job).
# Evidence: results/zk60_1b_native_20261017/t5/<variant>-L<layer>-<seq>/
set -u
D=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
X=$D/t5/zk60_trained_block.release.bin
E=$1; L=$2; S=$3; shift 3
V=$(basename "$E"); R=$D/t5/$V-L$L-$S
mkdir -p "$R"
python3 $G run --class cpu --need-gib 3 --cap-gib 5 --label t5-prove-$V-L$L --wait-secs 7200 --max-secs 3600 \
  --log "$R/prove.log" --done "$R/prove.done" --result-json "$R/prove.guard.json" \
  -- $X prove --export "$E" --layer "$L" --seq "$S" --out "$R/artifact" --controls "$@"
rc=$?
[ $rc -eq 0 ] || { echo "prove exit $rc"; exit $rc; }
ID=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['trained_statement_identity'])" "$R/artifact/statement.json")
python3 $G run --class cpu --need-gib 2 --cap-gib 4 --label t5-verify-$V-L$L --wait-secs 7200 --max-secs 1800 \
  --log "$R/verify.log" --done "$R/verify.done" --result-json "$R/verify.guard.json" \
  -- $X verify --export "$E" --layer "$L" --artifact "$R/artifact" --expect-statement "$ID" --controls "$@"
echo "verify exit $?"
