#!/bin/bash
# TOKEN ROUND 14 (rung R-C3 on native R12b): the freeze chain for ops/zkp-mvp/token-io-r14.
#  1. candidate manifest r14A (before the suite)
#  2. the FULL suite s18 once, --no-fail-fast, --test-threads=8 (need 8.5 / cap 10: s17 peaked 7.12 GiB RSS,
#     7.26 cgroup; the brief's declaration)
#  3. manifest r14B after the suite, compared with r14A (expect no source change)
#  4. the classifier CLI binary (example zk60_classify) -> cli/zk60_classify.r14.release.bin + sha256 + BUILD note
#  5. the short item through the NAMED r14 binary, each command its own process (the ignored r14 test)
#  6. the P-18 CLI-path capture through the r14 binary (bundle outside the repo, for the gate's §10 item 2)
#  7. the ignored Shieldstral R12b-path test, ONCE this round (streams the 7.7 GB checkpoint; need 1.5 / cap 2.5)
# Each guarded step waits while r14/HOLD or the guard-fix WINDOW_HOLD exists. Marker logs/r14_chain.done = 0 when
# all passed, else the failing step's name. The freeze copy itself is done by hand (tools/freeze14.py freeze).
R=/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017
T=$R/r14
L=$T/logs
H=/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io-r14/hashline
CARGO=/home/victor/.cargo/bin/cargo
G="python3 /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
W=/home/victor/IntelligenceRegulation/results/zk60_guard_fix_20261021/WINDOW_HOLD
F=$T/tools/freeze14.py
FX=/home/victor/zk60-artifacts/token-io/tmp-r14
ENV="/usr/bin/env TMPDIR=$FX HL_TIO_FIXTURE_DIR=$FX"
finish() { echo "$1" > $L/r14_chain.done; exit 0; }
hold() { while [ -e $T/HOLD ] || [ -e $W ]; do sleep 30; done; }
python3 $F snapshot $T/manifest_r14A.sha256 > $L/r14A-manifest.log 2>&1 || finish manifest-A
hold
$G --class cpu --need-gib 8.5 --cap-gib 10 --label tio14-s18-suite --wait-secs 14400 --max-secs 3600 --log $L/s18-suite.log --done $L/s18-suite.guard.done --result-json $L/s18-suite.guard.json -- $ENV $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --no-fail-fast -- --test-threads=8
echo $? > $L/s18-suite.exit
python3 $F snapshot $T/manifest_r14B.sha256 > $L/r14B-manifest.log 2>&1
python3 $F compare $T/manifest_r14A.sha256 $T/manifest_r14B.sha256 >> $L/r14B-manifest.log 2>&1
[ "$(cat $L/s18-suite.exit)" = "0" ] || finish s18
hold
$G --class build --need-gib 1.5 --cap-gib 3 --label tio14-b14-cli-build --wait-secs 14400 --max-secs 2400 --log $L/b14-cli-build.log --done $L/b14-cli-build.guard.done --result-json $L/b14-cli-build.guard.json -- $CARGO build --release --offline --locked -j2 --manifest-path $H/Cargo.toml --example zk60_classify
echo $? > $L/b14-cli-build.exit
[ "$(cat $L/b14-cli-build.exit)" = "0" ] || finish b14
D=$R/cli
B=$D/zk60_classify.r14.release.bin
cp $H/target/release/examples/zk60_classify $B || finish copy
sha256sum $B > $D/binaries_r14.sha256
BSHA=$(cut -c1-64 $D/binaries_r14.sha256)
{
  echo "zk60_classify round-14 CPU binary (rung R-C3: short items as one chunk of their length, pad positions pinned to the public pad id; the tables bound to the model in the library (REVIEW_R13 N-r13-1); statement schema zk60-classify-run/3; native R12b base)"
  echo "file:      $B"
  echo "sha256:    $BSHA"
  echo "built:     $(date -u +%FT%TZ) on $(hostname), by r14/tools/r14_chain.sh (log r14/logs/b14-cli-build.log)"
  echo "command:   $CARGO build --release --offline --locked -j2 --manifest-path $H/Cargo.toml --example zk60_classify"
  echo "toolchain: $(/home/victor/.cargo/bin/rustc -V); $($CARGO -V)"
  echo "features:  the crate's defaults only; gpu-cuda NOT enabled (cudarc is not compiled in): CPU backend only."
  echo "profile:   [profile.release] opt-level 3, codegen-units 1, lto fat, panic abort, debug false (hashline/Cargo.toml)"
  echo "rustflags: none (no RUSTFLAGS, no .cargo/config in the tree or \$HOME); default target, no target-cpu"
  echo "source:    the lane tree ops/zkp-mvp/token-io-r14 = r14/manifest_r14A.sha256 (list sha256 $(sha256sum $T/manifest_r14A.sha256 | cut -c1-64))"
  echo "scope:     the development rung registered (Shieldstral's tied path wired and tested, no Shieldstral classifier run profile yet); a build record, not a privacy acceptance; unreviewed"
} > $D/zk60_classify.r14.BUILD.txt
hold
$G --class cpu --need-gib 1.0 --cap-gib 2.0 --label tio14-bin-short --wait-secs 14400 --max-secs 900 --log $L/bin-short-r14.log --done $L/bin-short-r14.guard.done --result-json $L/bin-short-r14.guard.json -- $ENV HL_PB_CLI_BIN=$B $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- private_block::token_io::classify_r14_tests::r14_a_short_item_proves_and_verifies_through_the_named_binary_in_fresh_processes --exact --ignored --nocapture
echo $? > $L/bin-short-r14.exit
[ "$(cat $L/bin-short-r14.exit)" = "0" ] || finish bin-short
CAP=/home/victor/zk60-artifacts/token-io/captures/classify-rc3-cli-p18-r14
hold
$G --class cpu --need-gib 1.0 --cap-gib 2.0 --label tio14-p18-cli --wait-secs 14400 --max-secs 900 --log $L/p18-cli-r14.log --done $L/p18-cli-r14.guard.done --result-json $L/p18-cli-r14.guard.json -- $ENV HL_PB_CAPTURE_DIR=$CAP HL_PB_CLI_BIN=$B HL_PB_CLI_BIN_SHA256=$BSHA HL_RUN_CAPTURE_PUBLIC_TABLES=1 $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- private_block::token_io::classify_capture_tests::capture_the_classify_cli_verify_path --exact --ignored --nocapture
echo $? > $L/p18-cli-r14.exit
[ "$(cat $L/p18-cli-r14.exit)" = "0" ] || finish p18
hold
$G --class cpu --need-gib 1.5 --cap-gib 2.5 --label tio14-shieldstral-r12b --wait-secs 14400 --max-secs 1200 --log $L/shieldstral-r12b.log --done $L/shieldstral-r12b.guard.done --result-json $L/shieldstral-r12b.guard.json -- $ENV ZK60_RC2_SHIELDSTRAL_EXPORT=/home/victor/IntelligenceRegulation/results/zk60_shieldstral_export_20261026/dg_r12b_t256 $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- private_block::token_io::classify_tied_tests::rc2_the_shieldstral_export_tables_are_recomputed_through_native_r12b --exact --ignored --nocapture
echo $? > $L/shieldstral-r12b.exit
[ "$(cat $L/shieldstral-r12b.exit)" = "0" ] || finish shieldstral
finish 0
