#!/bin/bash
# TOKEN ROUND 14, the FAILING-FIRST run (r14-red): the r14 tree = frozen-r13's code plus the new
# round-14 tests (classify_r14_tests.rs, the capture-fixture test) and four test-only visibility
# words in classify_cli_tests.rs. Expected RED: the library accepts doctored tables (N-r13-1), the
# short item is refused, the capture fixture is not the derived tables; and the named r13 binary
# refuses the short item in a fresh process.
#  1. build from scratch + the focused tests (need 3.7 / cap 4.5: a1's cgroup 2.99 GiB + 25%)
#  2. the ignored binary test with the frozen r13 binary (light: the binary's prove is ~3 s, 0.2 GiB)
# Each guarded step waits while r14/HOLD or the guard-fix WINDOW_HOLD exists. Marker logs/r14_red.done.
R=/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017
T=$R/r14
L=$T/logs
H=/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io-r14/hashline
CARGO=/home/victor/.cargo/bin/cargo
G="python3 /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
W=/home/victor/IntelligenceRegulation/results/zk60_guard_fix_20261021/WINDOW_HOLD
hold() { while [ -e $T/HOLD ] || [ -e $W ]; do sleep 30; done; }
hold
$G --class build --need-gib 3.7 --cap-gib 4.5 --label tio14-red-build-tests --wait-secs 14400 --max-secs 2400 --log $L/red-tests.log --done $L/red-tests.guard.done --result-json $L/red-tests.guard.json -- /usr/bin/env TMPDIR=/home/victor/zk60-artifacts/token-io/tmp-r14 $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- token_io::classify_r14_tests token_io::classify_capture_tests::r14_ --test-threads=4
echo $? > $L/red-tests.exit
hold
$G --class cpu --need-gib 1.0 --cap-gib 2.0 --label tio14-red-r13-binary --wait-secs 14400 --max-secs 600 --log $L/red-r13-binary.log --done $L/red-r13-binary.guard.done --result-json $L/red-r13-binary.guard.json -- /usr/bin/env TMPDIR=/home/victor/zk60-artifacts/token-io/tmp-r14 HL_PB_CLI_BIN=$R/cli/zk60_classify.r13.release.bin $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- private_block::token_io::classify_r14_tests::r14_a_short_item_proves_and_verifies_through_the_named_binary_in_fresh_processes --exact --ignored --nocapture
echo $? > $L/red-r13-binary.exit
echo "tests=$(cat $L/red-tests.exit) r13-binary=$(cat $L/red-r13-binary.exit)" > $L/r14_red.done
