#!/bin/bash
# TOKEN ROUND 14, a focused GREEN batch: build + `--lib` tests token_io::classify (classify_tests,
# classify_cli_tests, classify_tied_tests, classify_capture_tests, classify_r14_tests) and the registry
# gates s24 / s25 / s33 / hash_domain plus run_capture. Usage: r14_green.sh <tag>; marker logs/<tag>.done.
# need 3.9 / cap 4.8 (g2's build + tests peaked at 3.12 GiB RSS; +25%: a >= 3 GiB job, one at a time box-wide). Waits while r14/HOLD or the
# guard-fix WINDOW_HOLD exists.
TAG=$1
R=/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017
T=$R/r14
L=$T/logs
H=/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io-r14/hashline
CARGO=/home/victor/.cargo/bin/cargo
G="python3 /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
W=/home/victor/IntelligenceRegulation/results/zk60_guard_fix_20261021/WINDOW_HOLD
while [ -e $T/HOLD ] || [ -e $W ]; do sleep 30; done
$G --class build --need-gib 3.9 --cap-gib 4.8 --label tio14-$TAG --wait-secs 14400 --max-secs 2400 --log $L/$TAG.log --done $L/$TAG.guard.done --result-json $L/$TAG.guard.json -- /usr/bin/env TMPDIR=/home/victor/zk60-artifacts/token-io/tmp-r14 HL_TIO_FIXTURE_DIR=/home/victor/zk60-artifacts/token-io/tmp-r14 $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- token_io::classify s24 s25 s33 hash_domain run_capture --test-threads=4
echo $? > $L/$TAG.done
