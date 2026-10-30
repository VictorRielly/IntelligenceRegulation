#!/bin/bash
# TOKEN ROUND 15: the freeze chain for ops/zkp-mvp/token-io-r15.
#  1. candidate manifest r15A (before the suite)
#  2. the FULL suite s19 once, --no-fail-fast, --test-threads=8 (need 8.5 / cap 10: s18 peaked 7.22 GiB RSS; the brief's declaration)
#  3. manifest r15B after the suite, compared with r15A (expect no source change)
#  4. the classifier CLI binary (example zk60_classify) -> cli/zk60_classify.r15.release.bin + sha256 + BUILD note
#  5. N-r14-1 through the NAMED r15 binary, each label its own process (the ignored r15 test)
#  6. the r14 short item through the r15 binary (the ignored r14 test; its label now passes --expect-total)
#  7. cross-binary: r15 and r14 receipts verify with the other binary (the ignored r15 test)
#  8. the P-18 CLI-path capture through the r15 binary (bundle outside the repo)
#  9. H18-1: the CLI-path capture of an 11-id short item through the r15 binary (bundle outside the repo; the published
#     statement copied to r15/)
# No Shieldstral stream this round: the tied path is unchanged (classify_tied.rs byte-identical to frozen-r14).
# Each guarded step waits while r15/HOLD or the guard-fix WINDOW_HOLD exists, honours the lean-memory rule before the
# >= 3 GiB suite, and leaves a waiting sol- / release / astra- job a gap. Marker logs/r15_chain.done = 0 when all
# passed, else the failing step's name. The freeze copy itself is done by hand (tools/freeze15.py freeze).
source /home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r15/tools/r15_common.sh
finish() { echo "$1" > $L/r15_chain.done; exit 0; }
step() { echo "$(date -u +%FT%TZ) $1" >> $L/queue.log; }
python3 $F snapshot $T/manifest_r15A.sha256 > $L/r15A-manifest.log 2>&1 || finish manifest-A
hold; gap; lean; step s19-suite
$G --class cpu --need-gib 8.5 --cap-gib 10 --label tio15-s19-suite --wait-secs 14400 --max-secs 3600 --log $L/s19-suite.log --done $L/s19-suite.guard.done --result-json $L/s19-suite.guard.json -- $ENV $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --no-fail-fast -- --test-threads=8
echo $? > $L/s19-suite.exit
python3 $F snapshot $T/manifest_r15B.sha256 > $L/r15B-manifest.log 2>&1
python3 $F compare $T/manifest_r15A.sha256 $T/manifest_r15B.sha256 >> $L/r15B-manifest.log 2>&1
[ "$(cat $L/s19-suite.exit)" = "0" ] || finish s19
hold; gap; step b15-cli-build
$G --class build --need-gib 1.5 --cap-gib 3 --label tio15-b15-cli-build --wait-secs 14400 --max-secs 2400 --log $L/b15-cli-build.log --done $L/b15-cli-build.guard.done --result-json $L/b15-cli-build.guard.json -- $CARGO build --release --offline --locked -j2 --manifest-path $H/Cargo.toml --example zk60_classify
echo $? > $L/b15-cli-build.exit
[ "$(cat $L/b15-cli-build.exit)" = "0" ] || finish b15
D=$R/cli
B=$D/zk60_classify.r15.release.bin
B14=$D/zk60_classify.r14.release.bin
cp $H/target/release/examples/zk60_classify $B || finish copy
sha256sum $B > $D/binaries_r15.sha256
BSHA=$(cut -c1-64 $D/binaries_r15.sha256)
{
  echo "zk60_classify round-15 CPU binary (rung R-C3 as round 14, plus REVIEW_R14 N-r14-1: label requires --expect-total N, the post's own token count, and refuses a chunk set that does not cover exactly [0, N); statement schema zk60-classify-run/3 unchanged; native R12b base)"
  echo "file:      $B"
  echo "sha256:    $BSHA"
  echo "built:     $(date -u +%FT%TZ) on $(hostname), by r15/tools/r15_chain.sh (log r15/logs/b15-cli-build.log)"
  echo "command:   $CARGO build --release --offline --locked -j2 --manifest-path $H/Cargo.toml --example zk60_classify"
  echo "toolchain: $(/home/victor/.cargo/bin/rustc -V); $($CARGO -V)"
  echo "features:  the crate's defaults only; gpu-cuda NOT enabled (cudarc is not compiled in): CPU backend only."
  echo "profile:   [profile.release] opt-level 3, codegen-units 1, lto fat, panic abort, debug false (hashline/Cargo.toml)"
  echo "rustflags: none (no RUSTFLAGS, no .cargo/config in the tree or \$HOME); default target, no target-cpu"
  echo "source:    the lane tree ops/zkp-mvp/token-io-r15 = r15/manifest_r15A.sha256 (list sha256 $(sha256sum $T/manifest_r15A.sha256 | cut -c1-64))"
  echo "scope:     the development rung registered (Shieldstral's tied path wired and tested, no Shieldstral classifier run profile yet); a build record, not a privacy acceptance; unreviewed"
} > $D/zk60_classify.r15.BUILD.txt
hold; gap; step bin-label
$G --class cpu --need-gib 1.0 --cap-gib 2.0 --label tio15-bin-label --wait-secs 14400 --max-secs 900 --log $L/bin-label-r15.log --done $L/bin-label-r15.guard.done --result-json $L/bin-label-r15.guard.json -- $ENV HL_PB_CLI_BIN=$B $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- private_block::token_io::classify_r15_tests::r15_label_expect_total_through_the_named_binary_in_fresh_processes --exact --ignored --nocapture
echo $? > $L/bin-label-r15.exit
[ "$(cat $L/bin-label-r15.exit)" = "0" ] || finish bin-label
hold; gap; step bin-short
$G --class cpu --need-gib 1.0 --cap-gib 2.0 --label tio15-bin-short --wait-secs 14400 --max-secs 900 --log $L/bin-short-r15.log --done $L/bin-short-r15.guard.done --result-json $L/bin-short-r15.guard.json -- $ENV HL_PB_CLI_BIN=$B $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- private_block::token_io::classify_r14_tests::r14_a_short_item_proves_and_verifies_through_the_named_binary_in_fresh_processes --exact --ignored --nocapture
echo $? > $L/bin-short-r15.exit
[ "$(cat $L/bin-short-r15.exit)" = "0" ] || finish bin-short
hold; gap; step xbin
$G --class cpu --need-gib 1.0 --cap-gib 2.0 --label tio15-xbin --wait-secs 14400 --max-secs 900 --log $L/xbin-r15-r14.log --done $L/xbin-r15-r14.guard.done --result-json $L/xbin-r15-r14.guard.json -- $ENV HL_PB_CLI_BIN=$B HL_PB_CLI_BIN_OTHER=$B14 $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- private_block::token_io::classify_r15_tests::r15_receipts_cross_verify_between_two_named_binaries --exact --ignored --nocapture
echo $? > $L/xbin-r15-r14.exit
[ "$(cat $L/xbin-r15-r14.exit)" = "0" ] || finish xbin
CAP=/home/victor/zk60-artifacts/token-io/captures/classify-rc3-cli-p18-r15
hold; gap; step p18-cli
$G --class cpu --need-gib 1.0 --cap-gib 2.0 --label tio15-p18-cli --wait-secs 14400 --max-secs 900 --log $L/p18-cli-r15.log --done $L/p18-cli-r15.guard.done --result-json $L/p18-cli-r15.guard.json -- $ENV HL_PB_CAPTURE_DIR=$CAP HL_PB_CLI_BIN=$B HL_PB_CLI_BIN_SHA256=$BSHA HL_RUN_CAPTURE_PUBLIC_TABLES=1 $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- private_block::token_io::classify_capture_tests::capture_the_classify_cli_verify_path --exact --ignored --nocapture
echo $? > $L/p18-cli-r15.exit
[ "$(cat $L/p18-cli-r15.exit)" = "0" ] || finish p18
CAPS=/home/victor/zk60-artifacts/token-io/captures/classify-rc3-cli-short11-r15
hold; gap; step h18-short-cli
$G --class cpu --need-gib 1.0 --cap-gib 2.0 --label tio15-h18-short-cli --wait-secs 14400 --max-secs 900 --log $L/h18-short-cli-r15.log --done $L/h18-short-cli-r15.guard.done --result-json $L/h18-short-cli-r15.guard.json -- $ENV HL_PB_CAPTURE_DIR=$CAPS HL_PB_CLI_BIN=$B HL_PB_CLI_BIN_SHA256=$BSHA HL_RUN_CAPTURE_PUBLIC_TABLES=1 HL_PB_CLI_SHORT_N=11 HL_PB_CLI_STATEMENT_OUT=$T/classify-rc3-cli-short11-r15.statement.json $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- private_block::token_io::classify_capture_tests::capture_a_short_item_through_the_classify_cli --exact --ignored --nocapture
echo $? > $L/h18-short-cli-r15.exit
[ "$(cat $L/h18-short-cli-r15.exit)" = "0" ] || finish h18
finish 0
