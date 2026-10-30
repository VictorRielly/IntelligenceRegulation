#!/bin/bash
# TOKEN ROUND 16b, step 1 (failing first): the round's two new tests on the r16b tree BEFORE the F-1 fix (classify.rs
# still frozen-r16's bytes). Expected: the F-1 test FAILS (both profiles admit four policies, the card among them);
# the N-r16-1 test PASSES (the frozen figures are right; its kill is shown by the bits-l mutant later).
# From-scratch test build in the new tree + the two tests, one thread (one 805 MB table set at a time).
# Declared need 2.9 / cap 4.2 GiB (measured: round-16 mutant runs = incremental build + one test, 2.26-2.33 GiB RSS;
# the reviewer's from-scratch test build 2.25 GiB; + 25%). Marker logs/red.done = the cargo exit code.
source /home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r16b/tools/r16b_common.sh
hold; gap; lean; step "red: the two r16b tests on the unfixed tree"
sha256sum $H/src/private_block/token_io/classify.rs > $L/red.classify.sha256
$G --class build --need-gib 2.9 --cap-gib 4.2 --label tio16b-red --wait-secs 14400 --max-secs 2400 --log $L/red.log --done $L/red.guard.done --result-json $L/red.guard.json -- $ENV $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- $T16B --test-threads=1 --nocapture
echo $? > $L/red.done
step "red end $(cat $L/red.done)"
