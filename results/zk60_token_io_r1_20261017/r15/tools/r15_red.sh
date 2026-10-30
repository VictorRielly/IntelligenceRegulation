#!/bin/bash
# TOKEN ROUND 15, the FAILING-FIRST run (r15-red): the r15 tree = frozen-r14's code plus the new round-15 tests
# (classify_r15_tests.rs: N-r14-1, the label's whole-post check; the F18-1 slot-list tests in classify_capture_tests.rs
# and capture_tests.rs) and one test mod line in token_io.rs. Expected RED: round 14's label has no --expect-total
# (exit 2) and labels a truncated proof set without it (exit 0); the classifier and token run files list 24 slot
# triples under n_slots 23; and the named r14 binary fails the same label cases in fresh processes.
#  1. build from scratch + the focused tests (need 3.7 / cap 4.5: r13 a1's cgroup peak 2.99 GiB + 25%)
#  2. the ignored binary test with the frozen r14 binary (cpu 1.0 / 2.0: the rung's proves are ~2 s, 0.2 GiB)
# Each guarded step waits while r15/HOLD or the guard-fix WINDOW_HOLD exists. Marker logs/r15_red.done.
R=/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017
T=$R/r15
L=$T/logs
H=/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io-r15/hashline
CARGO=/home/victor/.cargo/bin/cargo
G="python3 /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
W=/home/victor/IntelligenceRegulation/results/zk60_guard_fix_20261021/WINDOW_HOLD
X=/home/victor/zk60-artifacts/token-io/tmp-r15
hold() { while [ -e $T/HOLD ] || [ -e $W ]; do sleep 30; done; }
hold
$G --class build --need-gib 3.7 --cap-gib 4.5 --label tio15-red-build-tests --wait-secs 14400 --max-secs 2400 --log $L/red-tests.log --done $L/red-tests.guard.done --result-json $L/red-tests.guard.json -- /usr/bin/env TMPDIR=$X HL_TIO_FIXTURE_DIR=$X $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- token_io::classify_r15_tests r15_a_ --test-threads=4
echo $? > $L/red-tests.exit
hold
$G --class cpu --need-gib 1.0 --cap-gib 2.0 --label tio15-red-r14-binary --wait-secs 14400 --max-secs 600 --log $L/red-r14-binary.log --done $L/red-r14-binary.guard.done --result-json $L/red-r14-binary.guard.json -- /usr/bin/env TMPDIR=$X HL_TIO_FIXTURE_DIR=$X HL_PB_CLI_BIN=$R/cli/zk60_classify.r14.release.bin $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- private_block::token_io::classify_r15_tests::r15_label_expect_total_through_the_named_binary_in_fresh_processes --exact --ignored --nocapture
echo $? > $L/red-r14-binary.exit
echo "tests=$(cat $L/red-tests.exit) r14-binary=$(cat $L/red-r14-binary.exit)" > $L/r15_red.done
