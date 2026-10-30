#!/bin/bash
# TOKEN ROUND 15, a focused GREEN batch: build + `--lib` tests token_io::classify (classify_tests, classify_cli_tests,
# classify_tied_tests, classify_capture_tests, classify_r14_tests, classify_r15_tests), token_io::capture_tests,
# token_io::cli_tests, the two r3_tests fixtures N-r14-4 moved, and the registry gates s24 / s25 / s33 / hash_domain plus
# run_capture. Usage: r15_green.sh <tag>; marker logs/<tag>.done.
# need 3.9 / cap 4.8 (r14 g2's build + tests peaked at 3.12 GiB RSS; +25%: a >= 3 GiB job, one at a time box-wide).
# Waits while r15/HOLD or the guard-fix WINDOW_HOLD exists.
TAG=$1
R=/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017
T=$R/r15
L=$T/logs
H=/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io-r15/hashline
CARGO=/home/victor/.cargo/bin/cargo
G="python3 /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
W=/home/victor/IntelligenceRegulation/results/zk60_guard_fix_20261021/WINDOW_HOLD
X=/home/victor/zk60-artifacts/token-io/tmp-r15
while [ -e $T/HOLD ] || [ -e $W ]; do sleep 30; done
$G --class build --need-gib 3.9 --cap-gib 4.8 --label tio15-$TAG --wait-secs 14400 --max-secs 2400 --log $L/$TAG.log --done $L/$TAG.guard.done --result-json $L/$TAG.guard.json -- /usr/bin/env TMPDIR=$X HL_TIO_FIXTURE_DIR=$X $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- token_io::classify token_io::capture_tests token_io::cli_tests r3_tests::tr3_2 r3_tests::r3_the_table_loader s24 s25 s33 hash_domain run_capture --test-threads=4
echo $? > $L/$TAG.done
