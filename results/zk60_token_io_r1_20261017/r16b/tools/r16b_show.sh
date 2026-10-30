#!/bin/bash
# TOKEN ROUND 16b: the two r16b tests once more on the FIXED tree with --nocapture, for their printed evidence (the green
# batch ran them without it). The lib test binary is the suite's (no source change since); one thread. Need 2.9 / cap 4.2
# (the red run, same two tests + a from-scratch build: 2.26 GiB RSS; + 25%). Marker logs/show.done = the cargo exit code.
source /home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r16b/tools/r16b_common.sh
hold; gap; lean; step "show: the two r16b tests on the fixed tree, --nocapture"
sha256sum $H/src/private_block/token_io/classify.rs > $L/show.classify.sha256
$G --class build --need-gib 2.9 --cap-gib 4.2 --label tio16b-show --wait-secs 14400 --max-secs 1800 --log $L/show.log --done $L/show.guard.done --result-json $L/show.guard.json -- $ENV $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- $T16B --test-threads=1 --nocapture
echo $? > $L/show.done
step "show end $(cat $L/show.done)"
