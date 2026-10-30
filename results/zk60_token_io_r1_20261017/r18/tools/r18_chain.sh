#!/bin/bash
# TOKEN ROUND 18, the chain after the red run (Fix 1, Fix 2, the one-post rule, notes 7 / 9 / 14 applied; plant removed):
#  1. green: the focused batch (round 17's filter set; `token_io::classify` covers the batch module, its plan tests and
#     the round's tests), --test-threads=4; need 6.5 / cap 7.5 (r17's green 6.27 GiB RSS)
#  2. the RUNG BYTE-IDENTITY harness on the green test binary: r18/tools/run_fixed.sh rung8.bin -- the ignored test
#     batch::r18::r18_rung_batch_receipts_equal_single_proves_under_fixed_entropy (8 blocks: batch e0 r0 e1 r1, single 0
#     e0 r0, single 1 e1 r1); expect exit 0, unread 0. cpu class, need 1.0 / cap 2.0 (a rung fixture)
#  3. five test-killed mutants (r18/tools/mutate18.py): each an incremental build + its one killing test (need 2.9 /
#     cap 4.2: r18 red 2.32 GiB + 25%); exit 101 = killed; reverted with a sha256 check
#  4. two harness-killed mutants: job-order (expect 101: the test's byte comparison) and reused-draw (expect 97: unread
#     blocks); each a `--no-run` build, then the harness run; reverted
#  5. the tree manifest after the mutants = before
# Each step: turn (holds, other lanes first, lean memory). Marker logs/r18_chain.done = 0 or the failing step.
source /home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r18/tools/r18_common.sh
finish() { echo "$1" > $L/r18_chain.done; step "chain end $1"; exit 0; }
M=$T/tools/mutate18.py
EQ=/home/victor/zk60-artifacts/token-io/r18-a5-eq
EQT=private_block::token_io::classify_cli::batch::r18::r18_rung_batch_receipts_equal_single_proves_under_fixed_entropy
binof() { grep -o "Running unittests src/lib.rs ([^)]*)" "$1" | tail -1 | sed -E 's/.*\((.*)\)/\1/'; }
python3 $F snapshot $T/manifest_r18_green.sha256 > $L/green-manifest.log 2>&1
# 1. green
turn 6.5; step green
$G --class build --need-gib 6.5 --cap-gib 7.5 --label tio18-green --wait-secs 14400 --max-secs 3000 --log $L/green.log --done $L/green.guard.done --result-json $L/green.guard.json -- $ENV $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- token_io::classify token_io::capture_tests s24_tests s25_tests s33_tests hash_domain run_capture trained_accuracy accuracy_profile_tests plane_index --test-threads=4
echo $? > $L/green.exit
[ "$(cat $L/green.exit)" = "0" ] || finish green
BIN=$(binof $L/green.log); case $BIN in /*) ;; *) BIN=/home/victor/IntelligenceRegulation/$BIN;; esac
echo "$BIN" > $L/green.testbin
[ -x "$BIN" ] || finish green-testbin
# 2. the rung byte-identity harness
turn 1.0; step rung-eq
$G --class cpu --need-gib 1.0 --cap-gib 2.0 --label tio18-rung-eq --wait-secs 14400 --max-secs 300 --log $L/rung-eq.log --done $L/rung-eq.guard.done --result-json $L/rung-eq.guard.json -- bash $T/tools/run_fixed.sh $EQ/ent/rung8.bin -- $ENVC HL_R18_FIXED_ENTROPY=rung8 $BIN $EQT --exact --ignored --nocapture --test-threads=1
echo $? > $L/rung-eq.exit
[ "$(cat $L/rung-eq.exit)" = "0" ] || finish rung-eq
# 3. the test-killed mutants
python3 $F snapshot $T/manifest_r18_premut.sha256 > $L/mut-premut.log 2>&1
B=private_block::token_io::classify_cli::batch::r18
declare -A TEST=([fix1-revert]=$B::r18_a_failed_batch_leaves_no_receipt_statement_or_decommitment_behind [fix2-revert]=private_block::s25_tests::r18_the_census_reads_the_batch_files_through_their_path_lines [rng-plant]=private_block::s25_tests::no_profile_on_this_path_can_obtain_a_generator_other_than_from_the_operating_system [label-plant]=private_block::hash_domain::tests::every_absorb_label_on_the_path_is_in_the_table [one-post-revert]=$B::r18_a_second_post_or_any_repeated_flag_is_refused_before_anything_is_read)
RES=""
for m in fix1-revert fix2-revert rng-plant label-plant one-post-revert; do
  turn 2.9; step "mutant $m"
  python3 $M apply $m > $L/mut-$m.apply.log 2>&1 || { RES="$RES $m=apply-failed"; continue; }
  $G --class build --need-gib 2.9 --cap-gib 4.2 --label tio18-mut-$m --wait-secs 14400 --max-secs 2400 --log $L/mut-$m.log --done $L/mut-$m.guard.done --result-json $L/mut-$m.guard.json -- $ENV $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- ${TEST[$m]} --exact --nocapture
  echo $? > $L/mut-$m.exit
  python3 $M revert $m >> $L/mut-$m.apply.log 2>&1 || RES="$RES $m=REVERT-FAILED"
  RES="$RES $m=$(cat $L/mut-$m.exit)"
done
# 4. the harness-killed mutants
for m in job-order reused-draw; do
  turn 2.9; step "mutant $m (build)"
  python3 $M apply $m > $L/mut-$m.apply.log 2>&1 || { RES="$RES $m=apply-failed"; continue; }
  $G --class build --need-gib 2.9 --cap-gib 4.2 --label tio18-mut-$m-build --wait-secs 14400 --max-secs 2400 --log $L/mut-$m-build.log --done $L/mut-$m-build.guard.done --result-json $L/mut-$m-build.guard.json -- $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib --no-run
  echo $? > $L/mut-$m-build.exit
  MB=$(grep -o "Executable unittests src/lib.rs ([^)]*)" $L/mut-$m-build.log | tail -1 | sed -E 's/.*\((.*)\)/\1/'); case $MB in /*) ;; *) MB=/home/victor/IntelligenceRegulation/$MB;; esac
  if [ "$(cat $L/mut-$m-build.exit)" = "0" ] && [ -x "$MB" ]; then
    turn 1.0; step "mutant $m (harness)"
    $G --class cpu --need-gib 1.0 --cap-gib 2.0 --label tio18-mut-$m --wait-secs 14400 --max-secs 300 --log $L/mut-$m.log --done $L/mut-$m.guard.done --result-json $L/mut-$m.guard.json -- bash $T/tools/run_fixed.sh $EQ/ent/rung8.bin -- $ENVC HL_R18_FIXED_ENTROPY=rung8 $MB $EQT --exact --ignored --nocapture --test-threads=1
    echo $? > $L/mut-$m.exit
  else
    echo build-failed > $L/mut-$m.exit
  fi
  python3 $M revert $m >> $L/mut-$m.apply.log 2>&1 || RES="$RES $m=REVERT-FAILED"
  RES="$RES $m=$(cat $L/mut-$m.exit)"
done
# 5. the tree after = before
python3 $F snapshot $T/manifest_r18_postmut.sha256 > $L/mut-postmut.log 2>&1
python3 $F compare $T/manifest_r18_premut.sha256 $T/manifest_r18_postmut.sha256 >> $L/mut-postmut.log 2>&1
echo "$RES" > $L/r18_mut.done
grep -q "fix1-revert=101 fix2-revert=101 rng-plant=101 label-plant=101 one-post-revert=101 job-order=101 reused-draw=97" $L/r18_mut.done || finish mutations
grep -q "^changed 0: \[\]" $L/mut-postmut.log && grep -q "^added 0: \[\]" $L/mut-postmut.log && grep -q "^removed 0: \[\]" $L/mut-postmut.log || finish mutation-manifest
finish 0
