#!/bin/bash
# TOKEN ROUND 17, step 1 (failing first): the round's first two tests on the r17 tree BEFORE any recorder fix
# (plane_index.rs and run_capture.rs still frozen-r16b's bytes 13a7dd6f / cad25086; the tree = frozen-r16b + the gate's
# test-only H19-1 / H19-1-2 files adopted verbatim + one #[path] line + classify_r17_tests.rs). Expected: BOTH FAIL —
# the plane index does not build at an R13 shape (R19-PIN-1), so the recorder refuses the R13 rung run.
# From-scratch test build in the new tree + the two tests. Declared need 2.9 / cap 4.2 GiB (round 16b's red run: from-
# scratch test build + two tests, 2.26 GiB RSS; + 25%). Marker logs/red.done = the cargo exit code.
source /home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r17/tools/r17_common.sh
hold; gap; lean; step "red: the two r17 tests on the unfixed recorder"
sha256sum $H/src/private_block/plane_index.rs $H/src/private_block/run_capture.rs > $L/red.recorder.sha256
$G --class build --need-gib 2.9 --cap-gib 4.2 --label tio17-red --wait-secs 14400 --max-secs 2400 --log $L/red.log --done $L/red.guard.done --result-json $L/red.guard.json -- $ENV $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- $T17 --test-threads=2 --nocapture
echo $? > $L/red.done
step "red end $(cat $L/red.done)"
