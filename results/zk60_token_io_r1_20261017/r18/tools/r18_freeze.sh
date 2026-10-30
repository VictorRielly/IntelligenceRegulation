#!/bin/bash
# TOKEN ROUND 18, step F (only after the chain, the suite and step E all passed):
#  1. the r18 candidate binary (the bytes step E ran) and the r16b binary cross-verify rung receipts both ways (round 15's
#     two-binary test, as round 17; need 1.0 / cap 2.0)
#  2. ONE real receipt re-verified by the candidate in a fresh process (round 16's moderate-hate, made by e94cecf9…;
#     --expect-statement 29aeba6c…; one checkpoint stream; need 2.9 / cap 4.5, as round 17)
#  3. the tree = manifest_r18A (nothing moved since the suite); frozen-r18/ = exactly those files, re-hashed;
#     manifest_final_r18.sha256; the target binary = the candidate copy, copied to cli/zk60_classify.r18.release.bin
#  4. the diff vs frozen-r17
# Marker logs/r18_freeze.done = 0 or the failing step. The FROZEN note and the BUILD note are written by hand after.
source /home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r18/tools/r18_common.sh
finish() { echo "$1" > $L/r18_freeze.done; step "freeze end $1"; exit 0; }
EX=/home/victor/IntelligenceRegulation/results/zk60_shieldstral_export_20261026/native_low_h24_t128
EQ=/home/victor/zk60-artifacts/token-io/r18-a5-eq
CAND=$EQ/bin/zk60_classify.r18-candidate
D=$R/cli
BN=$D/zk60_classify.r18.release.bin
B16B=$D/zk60_classify.r16b.release.bin
grep " $CAND\$" $L/b18-cand.sha256 | sha256sum -c > $L/freeze-pins.log 2>&1 || finish candidate-pin
# 1. rung receipts cross-verify with the r16b binary
turn 1.0; step xbin
$G --class cpu --need-gib 1.0 --cap-gib 2.0 --label tio18-xbin --wait-secs 14400 --max-secs 900 --log $L/xbin-r18-r16b.log --done $L/xbin-r18-r16b.guard.done --result-json $L/xbin-r18-r16b.guard.json -- $ENV HL_PB_CLI_BIN=$CAND HL_PB_CLI_BIN_OTHER=$B16B $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- private_block::token_io::classify_r15_tests::r15_receipts_cross_verify_between_two_named_binaries --exact --ignored --nocapture
echo $? > $L/xbin-r18-r16b.exit
[ "$(cat $L/xbin-r18-r16b.exit)" = "0" ] || finish xbin
# 2. one real receipt, fresh process, one checkpoint stream
turn 2.9; step real-verify-hate
$G --class cpu --need-gib 2.9 --cap-gib 4.5 --label tio18-verify-hate --wait-secs 14400 --max-secs 1800 --log $L/verify-hate.log --done $L/verify-hate.guard.done --result-json $L/verify-hate.guard.json -- /usr/bin/env RAYON_NUM_THREADS=8 $CAND verify --export $EX --tables $EX/token_io --policy shieldstral-1.0-3b-moderate-hate/1 --artifact /home/victor/zk60-artifacts/token-io/r16-runs/hate-run --expect-statement 29aeba6c04a819cdbafde311f7c9d0c678d85aff22292ae6b9647761158a0bd1 --min-bits 95
echo $? > $L/verify-hate.exit
[ "$(cat $L/verify-hate.exit)" = "0" ] || finish verify-hate
# 3. the freeze
python3 $F snapshot $T/manifest_r18_final_check.sha256 > $L/final-manifest.log 2>&1
python3 $F compare $T/manifest_r18A.sha256 $T/manifest_r18_final_check.sha256 >> $L/final-manifest.log 2>&1
grep -q "^changed 0: \[\]" $L/final-manifest.log && grep -q "^added 0: \[\]" $L/final-manifest.log && grep -q "^removed 0: \[\]" $L/final-manifest.log || finish tree-moved
cmp $H/target/release/examples/zk60_classify $CAND > $L/freeze-bin.cmp 2>&1 || finish binary-moved
[ ! -e $BN ] || finish binary-exists
python3 $F freeze $T/manifest_r18A.sha256 $R/frozen-r18 > $L/freeze.log 2>&1 || finish freeze
cp $T/manifest_r18A.sha256 $R/manifest_final_r18.sha256
cp $CAND $BN
sha256sum $BN > $D/binaries_r18.sha256
cmp $BN $CAND >> $L/freeze-bin.cmp 2>&1 || finish binary-copy
# 4. vs frozen-r17
python3 $F compare $R/manifest_final_r17.sha256 $R/manifest_final_r18.sha256 > $T/r18A_vs_frozen_r17.txt 2>&1
diff -ruN $R/frozen-r17 $R/frozen-r18 > $T/r18A_vs_frozen_r17.diff 2>&1
finish 0
