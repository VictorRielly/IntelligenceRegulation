#!/bin/bash
# TOKEN ROUND 19b, the freeze (only after the chain, the suite and the checks passed): the tree = manifest_r19bA (nothing
# moved since the suite); frozen-r19b/ = exactly those files, re-hashed; manifest_final_r19b.sha256; the target binary =
# the candidate copy, copied to cli/zk60_classify.r19b.release.bin; the diff vs frozen-r19. Marker logs/r19b_freeze.done.
# The FROZEN note and the BUILD note are written by hand after. (r19/tools/r19_freeze.sh re-rooted.)
source /home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r19b/tools/r19b_common.sh
finish() { echo "$1" > $L/r19b_freeze.done; step "freeze end $1"; exit 0; }
EQ=/home/victor/zk60-artifacts/token-io/r19b
CAND=$EQ/bin/zk60_classify.r19b-candidate
D=$R/cli
BN=$D/zk60_classify.r19b.release.bin
grep " $CAND\$" $L/b19b-cand.sha256 | sha256sum -c > $L/freeze-pins.log 2>&1 || finish candidate-pin
python3 $F snapshot $T/manifest_r19b_final_check.sha256 > $L/final-manifest.log 2>&1
python3 $F compare $T/manifest_r19bA.sha256 $T/manifest_r19b_final_check.sha256 >> $L/final-manifest.log 2>&1
grep -q "^changed 0: \[\]" $L/final-manifest.log && grep -q "^added 0: \[\]" $L/final-manifest.log && grep -q "^removed 0: \[\]" $L/final-manifest.log || finish tree-moved
cmp $H/target/release/examples/zk60_classify $CAND > $L/freeze-bin.cmp 2>&1 || finish binary-moved
[ ! -e $BN ] || finish binary-exists
python3 $F freeze $T/manifest_r19bA.sha256 $R/frozen-r19b > $L/freeze.log 2>&1 || finish freeze
cp $T/manifest_r19bA.sha256 $R/manifest_final_r19b.sha256
cp $CAND $BN
sha256sum $BN > $D/binaries_r19b.sha256
cmp $BN $CAND >> $L/freeze-bin.cmp 2>&1 || finish binary-copy
python3 $F compare $R/manifest_final_r19.sha256 $R/manifest_final_r19b.sha256 > $T/r19bA_vs_frozen_r19.txt 2>&1
diff -ruN $R/frozen-r19 $R/frozen-r19b > $T/r19bA_vs_frozen_r19.diff 2>&1
finish 0
