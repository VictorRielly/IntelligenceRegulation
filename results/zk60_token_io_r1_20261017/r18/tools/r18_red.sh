#!/bin/bash
# TOKEN ROUND 18, THE RED RUN (failing-first): the r18 tree = Astra's five staged files + the neutral test hook
# (Spec / batch_command / check_coverage's policy list) + the round's tests + a PLANTED seeded generator in
# classify_batch.rs; WITHOUT Fix 1, Fix 2 or the one-post rule. Expected:
#   FAIL  batch::r18::r18_a_failed_batch_leaves_no_receipt_statement_or_decommitment_behind   (finding 1 reproduced)
#   FAIL  batch::r18::r18_a_second_post_or_any_repeated_flag_is_refused_before_anything_is_read
#   FAIL  s25_tests::r18_the_census_reads_the_batch_files_through_their_path_lines           (finding 2 reproduced)
#   PASS  s25_tests::no_profile_on_this_path_can_obtain_a_generator_other_than_from_the_operating_system
#         (the planted ZkRng::new is UNSEEN by the unfixed census)
#   PASS  the other r18 tests and the plan's 13 standalone tests (the staged code compiles, type-checks and runs)
# One build (the lib test binary from scratch: this tree has no target/ yet), need 2.9 / cap 4.2 (r17's red: 2.29 GiB
# RSS + 25%). Marker logs/r18_red.done = the cargo exit code (101 expected).
source /home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r18/tools/r18_common.sh
python3 $F snapshot $T/manifest_r18_red.sha256 > $L/red-manifest.log 2>&1
turn 2.9; step red
$G --class build --need-gib 2.9 --cap-gib 4.2 --label tio18-red --wait-secs 14400 --max-secs 2400 --log $L/red.log --done $L/red.guard.done --result-json $L/red.guard.json -- $ENV $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- classify_cli::batch:: s25_tests::r18_the_census s25_tests::no_profile_on_this_path --test-threads=4
echo $? > $L/r18_red.done
step "red end $(cat $L/r18_red.done)"
