#!/bin/bash
# NATIVE LANE R5b (final): the N-r4-d source pins (run_capture.rs, s24_tests.rs;
# both #[cfg(test)] modules, so no production byte and no CLI moves) were
# added after the 22:30 freeze. Run the full suite on the updated tree, and
# only if it is green and the tree did not move, RE-FREEZE R5b (superseding
# the 22:30 copy) under r5b/frozen-tree/.
set -u
D=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017
W=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b
$D/r5_suite2.sh r5b-suite2
SX=$(cat $D/r5b-suite2.done 2>/dev/null)
[ "$SX" = 0 ] || { echo "r5b-suite2 not green (guard exit $SX): no re-freeze"; exit 1; }
T=$(date -u +%Y-%m-%dT%H:%M:%SZ)
python3 -B $D/r5_manifest.py $D/r5b/manifest_frozen2_working.json "the working copy at the final R5b freeze $T" $W
A=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['tree_sha256'])" $D/r5b/manifest_frozen2_working.json)
S=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['tree_sha256'])" $D/r5/manifest_r5b-suite2.json)
[ "$A" = "$S" ] || { echo "the tree moved after r5b-suite2 started: no re-freeze"; exit 1; }
mv $D/r5b/frozen-tree $D/r5b/frozen-tree-2230-superseded
mv $D/r5b/manifest_frozen.json $D/r5b/manifest_frozen-2230-superseded.json
mv $D/r5b/FROZEN.txt $D/r5b/FROZEN-2230-superseded.txt
rsync -a --delete --exclude target --exclude target-gpu $W/ $D/r5b/frozen-tree/
python3 -B $D/r5_manifest.py $D/r5b/manifest_frozen.json "the R5b frozen review copy r5b/frozen-tree/ ($T; supersedes the 22:30 copy: + the N-r4-d source pins)" $D/r5b/frozen-tree
B=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['tree_sha256'])" $D/r5b/manifest_frozen.json)
[ "$A" = "$B" ] || { echo "the frozen copy differs from the working copy"; exit 1; }
printf 'R5b tree frozen for review at %s\ntree sha256 %s\nmanifest %s\ncopy %s\nsupersedes the 22:30:00Z freeze (tree 0a07d19a...): + the N-r4-d source pins (run_capture.rs, s24_tests.rs; test-only modules, the CLIs r5b/zk60_trained_block*.bin are unchanged)\n' "$T" "$A" "$D/r5b/manifest_frozen.json" "$D/r5b/frozen-tree/" > $D/r5b/FROZEN.txt
python3 - "$D" <<'PY'
import json, sys
d = sys.argv[1]
a = json.load(open(f"{d}/r5b/manifest_frozen-2230-superseded.json"))["files"]
b = json.load(open(f"{d}/r5b/manifest_frozen.json"))["files"]
print("files changed since the 22:30 freeze:", sorted(k for k in set(a) | set(b) if a.get(k) != b.get(k)))
PY
diff -ruN -x target -x target-gpu -x results $D/r5/frozen-tree $D/r5b/frozen-tree > $D/r5b/r5b-vs-r5.patch
echo "R5b re-frozen $T tree $A"
