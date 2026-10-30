#!/bin/bash
# TOKEN ROUND 19, the RED run (failing first): the round's five new tests on the RED tree (round 18's module reader and
# round 18's checkpoint constant behind the new interfaces). Expected: exit 101; FAIL
#   s25_tests::r19_the_module_follower_finds_every_module_line_shape            (round 18's reader misses shapes)
#   s25_tests::r19_the_module_follower_fails_on_every_module_line_it_cannot_classify (it skips what it cannot read)
#   tied_tables::derive::tests::r19_the_default_checkpoint_is_under_zk60_models_when_set_else_under_home_models
# PASS (already true in round 18): ..._declared_checkpoint_file_keeps_precedence..., ..._unset_on_this_box_...
# A fresh tree (no target/): the first build compiles every dependency. Guard build class, need 2.9 / cap 4.2 (r18's
# red run peaked 2.32 GiB RSS / 2.79 cgroup). Marker logs/r19_red.done = the cargo exit code.
source /home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r19/tools/r19_common.sh
turn 2.9; step red
$G --class build --need-gib 2.9 --cap-gib 4.2 --label tio19-red --wait-secs 14400 --max-secs 2400 --log $L/red.log --done $L/red.guard.done --result-json $L/red.guard.json -- $ENV $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- s25_tests::r19_ tied_tables::derive::tests::r19_ --test-threads=4
echo $? > $L/r19_red.done
step "red end $(cat $L/r19_red.done)"
