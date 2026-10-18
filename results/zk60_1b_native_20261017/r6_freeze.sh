#!/bin/bash
# NATIVE LANE R6: freeze the R6 tree for review once the full suite
# (r6-suite1) is green AND the working copy did not move after it started
# AND the R6 CPU CLI was built from that same tree (r6/manifest_cli.json).
# Copies to r6/frozen-tree/, writes r6/manifest_frozen.json, r6/FROZEN.txt
# and the patch r6/r6-vs-r5b.patch. Waits for the suite's marker first.
set -u
D=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017
W=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b
until [ -f $D/r6/r6-suite1.sh.done ]; do sleep 30; done
SX=$(cat $D/r6/r6-suite1.done 2>/dev/null)
[ "$SX" = 0 ] || { echo "r6-suite1 not green (guard exit $SX): no freeze"; exit 1; }
T=$(date -u +%Y-%m-%dT%H:%M:%SZ)
python3 -B $D/r5_manifest.py $D/r6/manifest_frozen_working.json "the working copy at the R6 freeze $T" $W
tree() { python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['tree_sha256'])" "$1"; }
A=$(tree $D/r6/manifest_frozen_working.json); S=$(tree $D/r6/manifest_r6-suite1.json); B0=$(tree $D/r6/manifest_cli.json)
[ "$A" = "$S" ] || { echo "the tree moved after r6-suite1 started ($S -> $A): no freeze"; exit 1; }
[ "$A" = "$B0" ] || { echo "the R6 CLI was built from tree $B0, not $A: no freeze"; exit 1; }
rsync -a --delete --exclude target --exclude target-gpu $W/ $D/r6/frozen-tree/
python3 -B $D/r5_manifest.py $D/r6/manifest_frozen.json "the R6 frozen review copy r6/frozen-tree/ ($T)" $D/r6/frozen-tree
B=$(tree $D/r6/manifest_frozen.json)
[ "$A" = "$B" ] || { echo "the frozen copy differs from the working copy"; exit 1; }
printf 'R6 tree frozen for review at %s\ntree sha256 %s\nmanifest %s\ncopy %s\nCLIs r6/zk60_trained_block.release.bin and .gpu.release.bin (r6/binaries.sha256), built from this tree\nsupersedes nothing: R5b (r5b/frozen-tree/, tree 44013397...) stays frozen\n' "$T" "$A" "$D/r6/manifest_frozen.json" "$D/r6/frozen-tree/" > $D/r6/FROZEN.txt
diff -ruN -x target -x target-gpu -x results $D/r5b/frozen-tree $D/r6/frozen-tree > $D/r6/r6-vs-r5b.patch
echo "R6 frozen $T tree $A; patch $(grep -c '' $D/r6/r6-vs-r5b.patch) lines"
