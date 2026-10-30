#!/bin/bash
# TOKEN ROUND 19b, the RED run (failing first): the round's five new tests on the RED tree (round 19's production-text
# cut and round 19's mod_items, without the include! check, behind the new interfaces). Expected: exit 101; FAIL
#   s25_tests::r19b_the_production_text_reads_every_item_after_the_tests_block_and_leaves_out_only_test_items
#   s25_tests::r19b_the_module_follower_refuses_include_outside_test_code
# PASS (true already in round 19; their mutants show what they catch):
#   s25_tests::r19b_every_rs_file_under_private_block_is_on_the_path_or_a_named_test_file
#   tied_tables::derive::tests::r19b_checkpoint_open_refuses_a_same_size_file_that_is_not_the_pinned_checkpoint
#   tied_tables::derive::tests::r19b_checkpoint_open_refuses_a_symlinked_checkpoint_file
# A fresh tree (no target/): the first build compiles every dependency. Guard build class, need 2.9 / cap 4.2 (r19's
# red run peaked 2.3 GiB RSS). The same-size test reads a 7.7 GB SPARSE file (page cache, bounded by the cap).
# Marker logs/r19b_red.done = the cargo exit code.
source /home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r19b/tools/r19b_common.sh
turn 2.9; step red
$G --class build --need-gib 2.9 --cap-gib 4.2 --label tio19b-red --wait-secs 14400 --max-secs 2400 --log $L/red.log --done $L/red.guard.done --result-json $L/red.guard.json -- $ENV $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- s25_tests::r19b_ tied_tables::derive::tests::r19b_ --test-threads=4
echo $? > $L/r19b_red.done
step "red end $(cat $L/r19b_red.done)"
