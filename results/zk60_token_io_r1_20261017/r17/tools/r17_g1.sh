#!/bin/bash
# TOKEN ROUND 17, g1 (argument: a tag, e.g. g1, g2): incremental test build after the fixes (H19-3, H19-4, the export
# replay, the adopted gate-19 hooks) + the round's four tests (--nocapture). Need 2.9 / cap 4.2 GiB (the red run peaked
# 2.29 GiB RSS; + 25%). Marker logs/<tag>.done = the cargo exit code.
source /home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r17/tools/r17_common.sh
TAG=${1:-g1}
hold; gap; lean; step "$TAG: the r17 tests on the fixed recorder"
sha256sum $H/src/private_block/plane_index.rs $H/src/private_block/run_capture.rs $H/src/private_block/token_io/gate19_capture_tests.rs $H/src/private_block/token_io/classify_r17_tests.rs > $L/$TAG.sources.sha256
$G --class build --need-gib 2.9 --cap-gib 4.2 --label tio17-$TAG --wait-secs 14400 --max-secs 2400 --log $L/$TAG.log --done $L/$TAG.guard.done --result-json $L/$TAG.guard.json -- $ENV $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- $T17 --test-threads=2 --nocapture
echo $? > $L/$TAG.done
step "$TAG end $(cat $L/$TAG.done)"
