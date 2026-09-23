#!/usr/bin/env bash
# Census check (review branch): build + run the lane's census filter and the
# checker's own tests, then the checker's #[ignore]d reproducers.
# Launched detached (setsid nohup) under the build lock; each run writes its
# own log and a .done marker holding its exit code.
set -u
WT=/home/victor/wt-zk60-block125m-review
OUT=$WT/results/zk60_census_check
M=$WT/hashline/Cargo.toml

# run 1: the lane's census tests + the checker's ordinary tests
flock /tmp/zk-build.lock cargo test --release --manifest-path "$M" --lib census_ -- --test-threads=6 > "$OUT/check-ordinary.log" 2>&1
echo $? > "$OUT/check-ordinary.done"

# run 2: the checker's reproducers (expected to FAIL today: they assert the property the census needs)
flock /tmp/zk-build.lock cargo test --release --manifest-path "$M" --lib census_check_tests -- --ignored --test-threads=2 > "$OUT/check-reproducers.log" 2>&1
echo $? > "$OUT/check-reproducers.done"
