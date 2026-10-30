#!/bin/bash
# TOKEN ROUND 16, chain 3 (after chain 2): the test-killing mutation runs, then the freeze chain:
#  1. r16_mut.sh: four mutants (gate, prehdr, bits, reuse), each killed by its test; tree manifest unchanged after
#  2. candidate manifest r16A
#  3. the FULL suite s20 once, --no-fail-fast, --test-threads=8 (need 9.5 / cap 11: s19 peaked 6.87 GiB RSS / 7.16
#     cgroup; this round's census adds two 805 MB Shieldstral classifier tables)
#  4. manifest r16B after the suite, compared with r16A
#  5. the zk60_classify binary rebuilt from the candidate and compared with the copy that made the real receipts
#     (cli/zk60_classify.r16.release.bin, e94cecf99f82…)
#  6. through the NAMED r16 binary (rung fixtures, fresh processes): the N-r14-1 label cases, the r14 short item,
#     r16 <-> r15 cross-verification of rung receipts (legacy bytes unchanged), the P-18 CLI-path capture
# Each step: hold, gap; lean before the >= 3 GiB ones. Marker logs/r16_chain3.done = 0 or the failing step.
source /home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r16/tools/r16_common.sh
finish() { echo "$1" > $L/r16_chain3.done; echo "$(date -u +%FT%TZ) chain3 end $1" >> $L/queue.log; exit 0; }
step() { echo "$(date -u +%FT%TZ) $1" >> $L/queue.log; }
step mutations
$T/tools/r16_mut.sh
grep -q "gate=101 prehdr=101 bits=101 reuse=101" $L/r16_mut.done || finish mutations
grep -q "^changed 0: \[\]" $L/mut-postmut.log && grep -q "^added 0: \[\]" $L/mut-postmut.log && grep -q "^removed 0: \[\]" $L/mut-postmut.log || finish mutation-manifest
python3 $F snapshot $T/manifest_r16A.sha256 > $L/r16A-manifest.log 2>&1 || finish manifest-A
hold; gap; lean; step s20-suite
$G --class cpu --need-gib 9.5 --cap-gib 11 --label tio16-s20-suite --wait-secs 14400 --max-secs 3600 --log $L/s20-suite.log --done $L/s20-suite.guard.done --result-json $L/s20-suite.guard.json -- $ENV $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --no-fail-fast -- --test-threads=8
echo $? > $L/s20-suite.exit
python3 $F snapshot $T/manifest_r16B.sha256 > $L/r16B-manifest.log 2>&1
python3 $F compare $T/manifest_r16A.sha256 $T/manifest_r16B.sha256 >> $L/r16B-manifest.log 2>&1
[ "$(cat $L/s20-suite.exit)" = "0" ] || finish s20
hold; gap; step b16-cli-build
$G --class build --need-gib 2.5 --cap-gib 3.5 --label tio16-b16-cli-build --wait-secs 14400 --max-secs 2400 --log $L/b16-cli-build.log --done $L/b16-cli-build.guard.done --result-json $L/b16-cli-build.guard.json -- $CARGO build --release --offline --locked -j2 --manifest-path $H/Cargo.toml --example zk60_classify
echo $? > $L/b16-cli-build.exit
[ "$(cat $L/b16-cli-build.exit)" = "0" ] || finish b16
D=$R/cli
B=$D/zk60_classify.r16.release.bin
B15=$D/zk60_classify.r15.release.bin
sha256sum $H/target/release/examples/zk60_classify > $L/b16-rebuilt.sha256
sha256sum $B > $D/binaries_r16.sha256
BSHA=$(cut -c1-64 $D/binaries_r16.sha256)
[ "$(cut -c1-64 $L/b16-rebuilt.sha256)" = "$BSHA" ] && echo "rebuilt = the receipts' binary" >> $L/b16-rebuilt.sha256 || echo "REBUILT BINARY DIFFERS from the receipts' binary" >> $L/b16-rebuilt.sha256
hold; gap; step bin-label
$G --class cpu --need-gib 1.0 --cap-gib 2.0 --label tio16-bin-label --wait-secs 14400 --max-secs 900 --log $L/bin-label-r16.log --done $L/bin-label-r16.guard.done --result-json $L/bin-label-r16.guard.json -- $ENV HL_PB_CLI_BIN=$B $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- private_block::token_io::classify_r15_tests::r15_label_expect_total_through_the_named_binary_in_fresh_processes --exact --ignored --nocapture
echo $? > $L/bin-label-r16.exit
[ "$(cat $L/bin-label-r16.exit)" = "0" ] || finish bin-label
hold; gap; step bin-short
$G --class cpu --need-gib 1.0 --cap-gib 2.0 --label tio16-bin-short --wait-secs 14400 --max-secs 900 --log $L/bin-short-r16.log --done $L/bin-short-r16.guard.done --result-json $L/bin-short-r16.guard.json -- $ENV HL_PB_CLI_BIN=$B $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- private_block::token_io::classify_r14_tests::r14_a_short_item_proves_and_verifies_through_the_named_binary_in_fresh_processes --exact --ignored --nocapture
echo $? > $L/bin-short-r16.exit
[ "$(cat $L/bin-short-r16.exit)" = "0" ] || finish bin-short
hold; gap; step xbin
$G --class cpu --need-gib 1.0 --cap-gib 2.0 --label tio16-xbin --wait-secs 14400 --max-secs 900 --log $L/xbin-r16-r15.log --done $L/xbin-r16-r15.guard.done --result-json $L/xbin-r16-r15.guard.json -- $ENV HL_PB_CLI_BIN=$B HL_PB_CLI_BIN_OTHER=$B15 $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- private_block::token_io::classify_r15_tests::r15_receipts_cross_verify_between_two_named_binaries --exact --ignored --nocapture
echo $? > $L/xbin-r16-r15.exit
[ "$(cat $L/xbin-r16-r15.exit)" = "0" ] || finish xbin
CAP=/home/victor/zk60-artifacts/token-io/captures/classify-rc3-cli-p18-r16
hold; gap; step p18-cli
$G --class cpu --need-gib 1.0 --cap-gib 2.0 --label tio16-p18-cli --wait-secs 14400 --max-secs 900 --log $L/p18-cli-r16.log --done $L/p18-cli-r16.guard.done --result-json $L/p18-cli-r16.guard.json -- $ENV HL_PB_CAPTURE_DIR=$CAP HL_PB_CLI_BIN=$B HL_PB_CLI_BIN_SHA256=$BSHA HL_RUN_CAPTURE_PUBLIC_TABLES=1 $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- private_block::token_io::classify_capture_tests::capture_the_classify_cli_verify_path --exact --ignored --nocapture
echo $? > $L/p18-cli-r16.exit
[ "$(cat $L/p18-cli-r16.exit)" = "0" ] || finish p18
finish 0
