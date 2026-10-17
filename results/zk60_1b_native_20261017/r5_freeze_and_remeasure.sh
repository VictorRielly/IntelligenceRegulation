#!/bin/bash
# NATIVE LANE round 5 (evening): once `r5-suite2` is green, (1) FREEZE the R5
# tree for review (a source copy under r5/frozen-tree/ plus its sha256
# manifest, checked equal to the working copy's), (2) rebuild both CLIs from
# it ("cli3": the controls / fit_the_shape fix of 19:15-19:18 UTC), (3) re-run
# the Llama-3-8B T32 ho00 CPU stack with its fresh verify and the 11 controls,
# and re-verify the existing TinyLlama T32 run directory with cli3.
set -u
D=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
W=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b
until [ -f $D/r5_suite2.done ]; do sleep 20; done
SX=$(cat $D/r5-suite2.done 2>/dev/null)
[ "$SX" = 0 ] || { echo "suite2 not green (guard exit $SX): no freeze"; exit 1; }
T=$(date -u +%Y-%m-%dT%H:%M:%SZ)
mkdir -p $D/r5/frozen-tree
rsync -a --delete --exclude target --exclude target-gpu $W/ $D/r5/frozen-tree/
python3 -B $D/r5_manifest.py $D/r5/manifest_frozen_working.json "the working copy at the R5 freeze $T" $W
python3 -B $D/r5_manifest.py $D/r5/manifest_frozen.json "the R5 frozen review copy r5/frozen-tree/ ($T)" $D/r5/frozen-tree
A=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['tree_sha256'])" $D/r5/manifest_frozen_working.json)
B=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['tree_sha256'])" $D/r5/manifest_frozen.json)
S2=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['tree_sha256'])" $D/r5/manifest_r5-suite2.json)
echo "freeze $T working $A copy $B suite2-script-start $S2"
[ "$A" = "$B" ] || { echo "the frozen copy differs from the working copy"; exit 1; }
# the suite compiled the tree as it stood when its guarded job STARTED; the
# last source edit before the freeze was written at 19:18:11 UTC
# (manifest_r5_1918.json), so the suite must have started after it and the
# frozen tree must be that tree
L18=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['tree_sha256'])" $D/r5/manifest_r5_1918.json)
[ "$A" = "$L18" ] || { echo "the tree moved after 19:18 UTC ($A vs $L18): no freeze"; exit 1; }
python3 -c "
import json,sys,datetime
g=json.load(open(sys.argv[1]))
end=datetime.datetime.strptime(g['ts_end'],'%Y-%m-%dT%H:%M:%SZ')
start=end-datetime.timedelta(seconds=g['child_wall_seconds'])
print('suite2 started', start.isoformat()+'Z')
sys.exit(0 if start > datetime.datetime(2026,10,17,19,18,11) else 1)
" $D/r5-suite2.guard.json || { echo "suite2 started before the last edit: no freeze"; exit 1; }
printf 'R5 tree frozen for review at %s\ntree sha256 %s\nmanifest %s\ncopy %s\n' "$T" "$A" "$D/r5/manifest_frozen.json" "$D/r5/frozen-tree/" > $D/r5/FROZEN.txt
# (2) cli3, keeping cli2's binaries for the record
mkdir -p $D/r5/cli2
cp -n $D/r5/zk60_trained_block.release.bin $D/r5/zk60_trained_block.gpu.release.bin $D/r5/binaries.sha256 $D/r5/cli2/
$D/r5_build_cli2.sh cli3 > $D/r5_build_cli3.out 2>&1 || { echo "cli3 build failed"; exit 1; }
cp $D/r5/binaries.sha256 $D/r5/binaries_cli3.sha256
# (3) the 8B T32 re-run (new directory) and the TinyLlama T32 re-verify
TAG=-cli3 VNEED=2.5 VCAP=8 $D/r5_stack.sh /home/victor/IntelligenceRegulation/results/zk60_8b_calibration_20261017/export/llama3_8b_pg_rot1_T32 cpu ho00 3 9
X=$D/r5/zk60_trained_block.release.bin
E=/home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929/export/pg_rot1_b4_T32_cal128
R=$D/r5/stack-pg_rot1_b4_T32_cal128-ho00-cpu
ID=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['trained_statement_identity'])" "$R/run/statement/statement.json")
python3 $G run --class cpu --need-gib 2.5 --cap-gib 5 --label r5-cli3-verify-tl-T32 --wait-secs 14400 --max-secs 3600 \
  --log "$R/verify-cli3.log" --done "$R/verify-cli3.done" --result-json "$R/verify-cli3.guard.json" \
  -- /usr/bin/env RAYON_NUM_THREADS=16 $X stack-verify --export "$E" --artifact "$R/run" --expect-statement "$ID" --controls
echo "TinyLlama T32 cli3 verify exit $?"
