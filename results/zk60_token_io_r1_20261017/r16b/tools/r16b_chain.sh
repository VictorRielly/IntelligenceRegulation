#!/bin/bash
# TOKEN ROUND 16b, the chain after the F-1 fix (classify.rs: the card policy #[cfg(test)], out of registered_policies):
#  1. green: the focused batch (round 16's g1 filter set: every token_io::classify* module incl. the r16b tests, s24,
#     s25, s33, hash_domain, run_capture, trained_accuracy, accuracy_profile_tests); need 5.0 / cap 6.0 (round 16's g1 /
#     g2 peaked 3.85 / 3.97 GiB RSS; + 25%)
#  2. mutants (r16b/tools/mutate16b.py): bits-l (REVIEW_R16 N-r16-1) and card-back (F-1), each an incremental build + its
#     one killing test (need 2.9 / cap 4.2: round 16's mutant runs 2.26-2.33 GiB + 25%); exit 101 = killed; reverted
#     with a sha256 check; the tree manifest after = before
#  3. candidate manifest r16bA; the FULL suite s21 once (--no-fail-fast, --test-threads=8; need 8.5 / cap 10: s20 peaked
#     6.80 GiB RSS / 7.09 cgroup; + 25%); manifest r16bB compared with r16bA
#  4. the zk60_classify release binary built from the candidate (need 2.5 / cap 3.5, as round 16), copied to
#     cli/zk60_classify.r16b.release.bin
#  5. ONE real receipt re-verified by the new binary in a fresh process (moderate-violence, made by e94cecf9…; the
#     category neither frozen-r16 binary re-verified yet; --expect-statement 29aeba6c…; one checkpoint stream;
#     need 2.9 / cap 4.5 = round 16's measured verify 2.24-2.32 GiB RSS + 25%)
#  6. the new binary and the frozen-r16 binary cross-verify rung receipts both ways (need 1.0 / cap 2.0)
# Each step: hold, gap; lean before the >= 3 GiB ones. Marker logs/r16b_chain.done = 0 or the failing step.
source /home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r16b/tools/r16b_common.sh
finish() { echo "$1" > $L/r16b_chain.done; step "chain end $1"; exit 0; }
M=$T/tools/mutate16b.py
# 1. green
hold; gap; lean; step green
sha256sum $H/src/private_block/token_io/classify.rs > $L/green.classify.sha256
$G --class build --need-gib 5.0 --cap-gib 6.0 --label tio16b-green --wait-secs 14400 --max-secs 3000 --log $L/green.log --done $L/green.guard.done --result-json $L/green.guard.json -- $ENV $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- token_io::classify s24_tests s25_tests s33_tests hash_domain run_capture trained_accuracy accuracy_profile_tests --test-threads=4
echo $? > $L/green.exit
[ "$(cat $L/green.exit)" = "0" ] || finish green
# 2. mutants
python3 $F snapshot $T/manifest_r16b_premut.sha256 > $L/mut-premut.log 2>&1
declare -A TEST=([bits-l]=$T_N1 [card-back]=$T_F1)
RES=""
for m in bits-l card-back; do
  hold; gap; step "mutant $m"
  python3 $M apply $m > $L/mut-$m.apply.log 2>&1 || { RES="$RES $m=apply-failed"; continue; }
  $G --class build --need-gib 2.9 --cap-gib 4.2 --label tio16b-mut-$m --wait-secs 14400 --max-secs 2400 --log $L/mut-$m.log --done $L/mut-$m.guard.done --result-json $L/mut-$m.guard.json -- $ENV $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- ${TEST[$m]} --exact --nocapture
  echo $? > $L/mut-$m.exit
  python3 $M revert $m >> $L/mut-$m.apply.log 2>&1 || RES="$RES $m=REVERT-FAILED"
  RES="$RES $m=$(cat $L/mut-$m.exit)"
done
python3 $F snapshot $T/manifest_r16b_postmut.sha256 > $L/mut-postmut.log 2>&1
python3 $F compare $T/manifest_r16b_premut.sha256 $T/manifest_r16b_postmut.sha256 >> $L/mut-postmut.log 2>&1
echo "$RES" > $L/r16b_mut.done
grep -q "bits-l=101 card-back=101" $L/r16b_mut.done || finish mutations
grep -q "^changed 0: \[\]" $L/mut-postmut.log && grep -q "^added 0: \[\]" $L/mut-postmut.log && grep -q "^removed 0: \[\]" $L/mut-postmut.log || finish mutation-manifest
# 3. the full suite
python3 $F snapshot $T/manifest_r16bA.sha256 > $L/r16bA-manifest.log 2>&1 || finish manifest-A
hold; gap; lean; step s21-suite
$G --class cpu --need-gib 8.5 --cap-gib 10 --label tio16b-s21-suite --wait-secs 14400 --max-secs 3600 --log $L/s21-suite.log --done $L/s21-suite.guard.done --result-json $L/s21-suite.guard.json -- $ENV $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --no-fail-fast -- --test-threads=8
echo $? > $L/s21-suite.exit
python3 $F snapshot $T/manifest_r16bB.sha256 > $L/r16bB-manifest.log 2>&1
python3 $F compare $T/manifest_r16bA.sha256 $T/manifest_r16bB.sha256 >> $L/r16bB-manifest.log 2>&1
[ "$(cat $L/s21-suite.exit)" = "0" ] || finish s21
# 4. the binary
hold; gap; step b16b-cli-build
$G --class build --need-gib 2.5 --cap-gib 3.5 --label tio16b-cli-build --wait-secs 14400 --max-secs 2400 --log $L/b16b-cli-build.log --done $L/b16b-cli-build.guard.done --result-json $L/b16b-cli-build.guard.json -- $CARGO build --release --offline --locked -j2 --manifest-path $H/Cargo.toml --example zk60_classify
echo $? > $L/b16b-cli-build.exit
[ "$(cat $L/b16b-cli-build.exit)" = "0" ] || finish b16b
D=$R/cli
BN=$D/zk60_classify.r16b.release.bin
BF=$D/zk60_classify.r16-frozen.release.bin
cp $H/target/release/examples/zk60_classify $BN
sha256sum $BN > $D/binaries_r16b.sha256
sha256sum $H/target/release/examples/zk60_classify >> $L/b16b-rebuilt.sha256
# 5. one real receipt, fresh process, one checkpoint stream
EX=/home/victor/IntelligenceRegulation/results/zk60_shieldstral_export_20261026/native_low_h24_t128
hold; gap; step real-verify-violence
$G --class cpu --need-gib 2.9 --cap-gib 4.5 --label tio16b-verify-violence --wait-secs 14400 --max-secs 1800 --log $L/verify-violence.log --done $L/verify-violence.guard.done --result-json $L/verify-violence.guard.json -- /usr/bin/env RAYON_NUM_THREADS=8 $BN verify --export $EX --tables $EX/token_io --policy shieldstral-1.0-3b-moderate-violence/1 --artifact /home/victor/zk60-artifacts/token-io/r16-runs/violence-run --expect-statement 29aeba6c04a819cdbafde311f7c9d0c678d85aff22292ae6b9647761158a0bd1 --min-bits 95
echo $? > $L/verify-violence.exit
[ "$(cat $L/verify-violence.exit)" = "0" ] || finish verify-violence
# 6. rung receipts cross-verify with the frozen-r16 binary
hold; gap; step xbin
$G --class cpu --need-gib 1.0 --cap-gib 2.0 --label tio16b-xbin --wait-secs 14400 --max-secs 900 --log $L/xbin-r16b-r16.log --done $L/xbin-r16b-r16.guard.done --result-json $L/xbin-r16b-r16.guard.json -- $ENV HL_PB_CLI_BIN=$BN HL_PB_CLI_BIN_OTHER=$BF $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- private_block::token_io::classify_r15_tests::r15_receipts_cross_verify_between_two_named_binaries --exact --ignored --nocapture
echo $? > $L/xbin-r16b-r16.exit
[ "$(cat $L/xbin-r16b-r16.exit)" = "0" ] || finish xbin
finish 0
