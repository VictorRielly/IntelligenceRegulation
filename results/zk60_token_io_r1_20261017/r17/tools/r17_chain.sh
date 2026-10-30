#!/bin/bash
# TOKEN ROUND 17, the chain after g1 passed (H19-3, H19-4, the export replay, the adopted gate-19 hooks):
#  1. green: the focused batch (round 16b's filter set + token_io::capture_tests + plane_index), --test-threads=4;
#     need 6.5 / cap 7.5 (round 16b's green peaked 5.20 GiB RSS; its note: next declaration 6.5 / 7.5)
#  2. mutants (r17/tools/mutate17.py): h19-3-off, h19-4-off, replay-blind, group-skip — each an incremental build + its
#     one killing test (need 2.9 / cap 4.2: the red run 2.29 GiB + 25%); exit 101 = killed; reverted with a sha256
#     check; the tree manifest after = before
#  3. candidate manifest r17A; the FULL suite s22 once (--no-fail-fast, --test-threads=8; need 9.9 / cap 11: s21 peaked
#     7.89 GiB RSS / 8.22 cgroup; + 25%); manifest r17B compared with r17A
#  4. the zk60_classify release binary built from the candidate (need 2.5 / cap 3.5), copied to
#     cli/zk60_classify.r17.release.bin, compared with the r16b binary dfb8025e…
#  5. the r17 binary and the r16b binary cross-verify rung receipts both ways (need 1.0 / cap 2.0)
#  6. ONE real receipt re-verified by the r17 binary in a fresh process (moderate-hate, made by e94cecf9…; the category
#     no r16b+ binary has re-verified yet; --expect-statement 29aeba6c…; one checkpoint stream; need 2.9 / cap 4.5 =
#     the measured verify 2.24-2.32 GiB RSS + 25%)
# Each step: hold, gap; lean before the >= 3 GiB ones. Marker logs/r17_chain.done = 0 or the failing step.
source /home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r17/tools/r17_common.sh
finish() { echo "$1" > $L/r17_chain.done; step "chain end $1"; exit 0; }
M=$T/tools/mutate17.py
P17=private_block::token_io::classify_capture_tests::gate19::r17
# 1. green
hold; gap; lean; step green
$G --class build --need-gib 6.5 --cap-gib 7.5 --label tio17-green --wait-secs 14400 --max-secs 3000 --log $L/green.log --done $L/green.guard.done --result-json $L/green.guard.json -- $ENV $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- token_io::classify token_io::capture_tests s24_tests s25_tests s33_tests hash_domain run_capture trained_accuracy accuracy_profile_tests plane_index --test-threads=4
echo $? > $L/green.exit
[ "$(cat $L/green.exit)" = "0" ] || finish green
# 2. mutants
python3 $F snapshot $T/manifest_r17_premut.sha256 > $L/mut-premut.log 2>&1
declare -A TEST=([h19-3-off]=$P17::r17_the_plane_index_builds_at_an_r13_shape_from_the_accuracy_layout [h19-4-off]=$P17::r17_an_r13_rung_classify_run_is_recorded_under_the_classifier_schema [replay-blind]=$P17::r17_a_recorded_table_that_disagrees_with_the_export_is_refused_by_the_replay [group-skip]=$P17::r17_an_r13_capture_with_table_values_records_every_statement_table_and_replays_it_against_the_export)
RES=""
for m in h19-3-off h19-4-off replay-blind group-skip; do
  hold; gap; step "mutant $m"
  python3 $M apply $m > $L/mut-$m.apply.log 2>&1 || { RES="$RES $m=apply-failed"; continue; }
  $G --class build --need-gib 2.9 --cap-gib 4.2 --label tio17-mut-$m --wait-secs 14400 --max-secs 2400 --log $L/mut-$m.log --done $L/mut-$m.guard.done --result-json $L/mut-$m.guard.json -- $ENV $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- ${TEST[$m]} --exact --nocapture
  echo $? > $L/mut-$m.exit
  python3 $M revert $m >> $L/mut-$m.apply.log 2>&1 || RES="$RES $m=REVERT-FAILED"
  RES="$RES $m=$(cat $L/mut-$m.exit)"
done
python3 $F snapshot $T/manifest_r17_postmut.sha256 > $L/mut-postmut.log 2>&1
python3 $F compare $T/manifest_r17_premut.sha256 $T/manifest_r17_postmut.sha256 >> $L/mut-postmut.log 2>&1
echo "$RES" > $L/r17_mut.done
grep -q "h19-3-off=101 h19-4-off=101 replay-blind=101 group-skip=101" $L/r17_mut.done || finish mutations
grep -q "^changed 0: \[\]" $L/mut-postmut.log && grep -q "^added 0: \[\]" $L/mut-postmut.log && grep -q "^removed 0: \[\]" $L/mut-postmut.log || finish mutation-manifest
# 3. the full suite
python3 $F snapshot $T/manifest_r17A.sha256 > $L/r17A-manifest.log 2>&1 || finish manifest-A
hold; gap; lean; step s22-suite
$G --class cpu --need-gib 9.9 --cap-gib 11 --label tio17-s22-suite --wait-secs 14400 --max-secs 3600 --log $L/s22-suite.log --done $L/s22-suite.guard.done --result-json $L/s22-suite.guard.json -- $ENV $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --no-fail-fast -- --test-threads=8
echo $? > $L/s22-suite.exit
python3 $F snapshot $T/manifest_r17B.sha256 > $L/r17B-manifest.log 2>&1
python3 $F compare $T/manifest_r17A.sha256 $T/manifest_r17B.sha256 >> $L/r17B-manifest.log 2>&1
[ "$(cat $L/s22-suite.exit)" = "0" ] || finish s22
# 4. the binary
hold; gap; step b17-cli-build
$G --class build --need-gib 2.5 --cap-gib 3.5 --label tio17-cli-build --wait-secs 14400 --max-secs 2400 --log $L/b17-cli-build.log --done $L/b17-cli-build.guard.done --result-json $L/b17-cli-build.guard.json -- $CARGO build --release --offline --locked -j2 --manifest-path $H/Cargo.toml --example zk60_classify
echo $? > $L/b17-cli-build.exit
[ "$(cat $L/b17-cli-build.exit)" = "0" ] || finish b17
D=$R/cli
BN=$D/zk60_classify.r17.release.bin
B16B=$D/zk60_classify.r16b.release.bin
cp $H/target/release/examples/zk60_classify $BN
sha256sum $BN > $D/binaries_r17.sha256
sha256sum $BN $B16B > $L/b17-vs-r16b.sha256
cmp $BN $B16B > $L/b17-vs-r16b.cmp 2>&1; echo "cmp exit $?" >> $L/b17-vs-r16b.cmp
# 5. rung receipts cross-verify with the r16b binary
hold; gap; step xbin
$G --class cpu --need-gib 1.0 --cap-gib 2.0 --label tio17-xbin --wait-secs 14400 --max-secs 900 --log $L/xbin-r17-r16b.log --done $L/xbin-r17-r16b.guard.done --result-json $L/xbin-r17-r16b.guard.json -- $ENV HL_PB_CLI_BIN=$BN HL_PB_CLI_BIN_OTHER=$B16B $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- private_block::token_io::classify_r15_tests::r15_receipts_cross_verify_between_two_named_binaries --exact --ignored --nocapture
echo $? > $L/xbin-r17-r16b.exit
[ "$(cat $L/xbin-r17-r16b.exit)" = "0" ] || finish xbin
# 6. one real receipt, fresh process, one checkpoint stream
EX=/home/victor/IntelligenceRegulation/results/zk60_shieldstral_export_20261026/native_low_h24_t128
hold; gap; step real-verify-hate
$G --class cpu --need-gib 2.9 --cap-gib 4.5 --label tio17-verify-hate --wait-secs 14400 --max-secs 1800 --log $L/verify-hate.log --done $L/verify-hate.guard.done --result-json $L/verify-hate.guard.json -- /usr/bin/env RAYON_NUM_THREADS=8 $BN verify --export $EX --tables $EX/token_io --policy shieldstral-1.0-3b-moderate-hate/1 --artifact /home/victor/zk60-artifacts/token-io/r16-runs/hate-run --expect-statement 29aeba6c04a819cdbafde311f7c9d0c678d85aff22292ae6b9647761158a0bd1 --min-bits 95
echo $? > $L/verify-hate.exit
[ "$(cat $L/verify-hate.exit)" = "0" ] || finish verify-hate
finish 0
