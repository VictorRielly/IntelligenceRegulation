#!/bin/bash
# TOKEN ROUND 18, step C (after r18_chain.sh passed):
#  1. candidate manifest r18A; the FULL suite s23 once (--no-fail-fast, --test-threads=8; need 9.9 / cap 11 = round 17's
#     s22 declaration: it peaked 7.82 GiB RSS / 8.16 cgroup); manifest r18B compared with r18A
#  2. the zk60_classify release binary built from the candidate (need 2.5 / cap 3.5), copied OUTSIDE the repo to
#     ~/zk60-artifacts/token-io/r18-a5-eq/bin/zk60_classify.r18-candidate (the binary step E runs; the freeze copies the
#     same bytes to cli/), sha256 recorded, compared with the r17 binary 81bd8624… (not byte-equal is expected: the
#     production code moved)
# Each step: turn (holds, other lanes first, lean memory). Marker logs/r18_suite.done = 0 or the failing step.
source /home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r18/tools/r18_common.sh
finish() { echo "$1" > $L/r18_suite.done; step "suite end $1"; exit 0; }
EQ=/home/victor/zk60-artifacts/token-io/r18-a5-eq
python3 $F snapshot $T/manifest_r18A.sha256 > $L/r18A-manifest.log 2>&1 || finish manifest-A
turn 9.9; step s23-suite
$G --class cpu --need-gib 9.9 --cap-gib 11 --label tio18-s23-suite --wait-secs 14400 --max-secs 3600 --log $L/s23-suite.log --done $L/s23-suite.guard.done --result-json $L/s23-suite.guard.json -- $ENV $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --no-fail-fast -- --test-threads=8
echo $? > $L/s23-suite.exit
python3 $F snapshot $T/manifest_r18B.sha256 > $L/r18B-manifest.log 2>&1
python3 $F compare $T/manifest_r18A.sha256 $T/manifest_r18B.sha256 >> $L/r18B-manifest.log 2>&1
[ "$(cat $L/s23-suite.exit)" = "0" ] || finish s23
grep -q "^changed 0: \[\]" $L/r18B-manifest.log && grep -q "^added 0: \[\]" $L/r18B-manifest.log && grep -q "^removed 0: \[\]" $L/r18B-manifest.log || finish suite-manifest
turn 2.5; step b18-cli-build
$G --class build --need-gib 2.5 --cap-gib 3.5 --label tio18-cli-build --wait-secs 14400 --max-secs 2400 --log $L/b18-cli-build.log --done $L/b18-cli-build.guard.done --result-json $L/b18-cli-build.guard.json -- $CARGO build --release --offline --locked -j2 --manifest-path $H/Cargo.toml --example zk60_classify
echo $? > $L/b18-cli-build.exit
[ "$(cat $L/b18-cli-build.exit)" = "0" ] || finish b18
mkdir -p $EQ/bin
cp $H/target/release/examples/zk60_classify $EQ/bin/zk60_classify.r18-candidate
sha256sum $H/target/release/examples/zk60_classify $EQ/bin/zk60_classify.r18-candidate $R/cli/zk60_classify.r17.release.bin $R/cli/zk60_classify.r16b.release.bin > $L/b18-cand.sha256
cmp $EQ/bin/zk60_classify.r18-candidate $R/cli/zk60_classify.r17.release.bin > $L/b18-vs-r17.cmp 2>&1; echo "cmp exit $?" >> $L/b18-vs-r17.cmp
finish 0
