#!/bin/bash
# TOKEN ROUND 15, g2: the incremental build after the cross-binary test was added (an #[ignore]d test in
# classify_r15_tests.rs), then the r15 test module and the label tests. need 3.9 / cap 4.8 (g1 peaked 2.97 GiB RSS,
# 3.40 cgroup). Marker logs/g2.done.
source /home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r15/tools/r15_common.sh
hold; gap; lean
$G --class build --need-gib 3.9 --cap-gib 4.8 --label tio15-g2 --wait-secs 14400 --max-secs 2400 --log $L/g2.log --done $L/g2.guard.done --result-json $L/g2.guard.json -- $ENV $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- token_io::classify_r15_tests token_io::classify_cli_tests --test-threads=4
echo $? > $L/g2.done
