#!/bin/bash
# NATIVE LANE: every layer of the export, one guarded prove job and one
# guarded fresh-process verify job per layer (no controls; layer 0 carries
# the controls in t5/a_export_T32-L0-ho00/). usage: t5_all_layers.sh <variant dir> <seq id>
set -u
D=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
X=$D/t5/zk60_trained_block.release.bin
E=$1; S=$2; V=$(basename "$E")
for L in $(seq 1 21); do
  R=$D/t5/all/$V-L$L-$S; mkdir -p "$R"
  python3 $G run --class cpu --need-gib 3 --cap-gib 5 --label t5-prove-$V-L$L --wait-secs 7200 --max-secs 1800 \
    --log "$R/prove.log" --done "$R/prove.done" --result-json "$R/prove.guard.json" \
    -- $X prove --export "$E" --layer "$L" --seq "$S" --out "$R/artifact"
  [ -f "$R/artifact/statement.json" ] || continue
  ID=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['trained_statement_identity'])" "$R/artifact/statement.json")
  python3 $G run --class cpu --need-gib 2 --cap-gib 4 --label t5-verify-$V-L$L --wait-secs 7200 --max-secs 1800 \
    --log "$R/verify.log" --done "$R/verify.done" --result-json "$R/verify.guard.json" \
    -- $X verify --export "$E" --layer "$L" --artifact "$R/artifact" --expect-statement "$ID"
done
echo all-done > $D/t5/all/ALL.done
