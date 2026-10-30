#!/bin/bash
# TOKEN ROUND 19b, after r19b_chain.sh passed (r19/tools/r19_suite.sh re-rooted):
#  1. candidate manifest r19bA; the FULL suite s24 once (--no-fail-fast, --test-threads=8), guard cpu need 11 / cap 12
#     (the brief; round 19's suite peaked 7.78 GiB RSS / 8.13 cgroup; the R19-1 test's 7.7 GB sparse read adds page
#     cache, bounded by the cap and freed when its fixture is removed); manifest r19bB = r19bA
#  2. the zk60_classify release binary from the candidate (build need 2.5 / cap 3.5), copied OUTSIDE the repo to
#     ~/zk60-artifacts/token-io/r19b/bin/zk60_classify.r19b-candidate (the bytes the checks run; the freeze copies them
#     to cli/), sha256 recorded, compared with r19's 841ba983… (not byte-equal is expected: the tree path is baked in)
# Marker logs/r19b_suite.done = 0 or the failing step.
source /home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r19b/tools/r19b_common.sh
finish() { echo "$1" > $L/r19b_suite.done; step "suite end $1"; exit 0; }
EQ=/home/victor/zk60-artifacts/token-io/r19b
python3 $F snapshot $T/manifest_r19bA.sha256 > $L/r19bA-manifest.log 2>&1 || finish manifest-A
turn 11; step s24-suite
$G --class cpu --need-gib 11 --cap-gib 12 --label tio19b-s24-suite --wait-secs 21600 --max-secs 3600 --log $L/s24-suite.log --done $L/s24-suite.guard.done --result-json $L/s24-suite.guard.json -- $ENV $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --no-fail-fast -- --test-threads=8
echo $? > $L/s24-suite.exit
python3 $F snapshot $T/manifest_r19bB.sha256 > $L/r19bB-manifest.log 2>&1
python3 $F compare $T/manifest_r19bA.sha256 $T/manifest_r19bB.sha256 >> $L/r19bB-manifest.log 2>&1
[ "$(cat $L/s24-suite.exit)" = "0" ] || finish s24
grep -q "^changed 0: \[\]" $L/r19bB-manifest.log && grep -q "^added 0: \[\]" $L/r19bB-manifest.log && grep -q "^removed 0: \[\]" $L/r19bB-manifest.log || finish suite-manifest
turn 2.5; step b19b-cli-build
$G --class build --need-gib 2.5 --cap-gib 3.5 --label tio19b-cli-build --wait-secs 14400 --max-secs 2400 --log $L/b19b-cli-build.log --done $L/b19b-cli-build.guard.done --result-json $L/b19b-cli-build.guard.json -- $CARGO build --release --offline --locked -j2 --manifest-path $H/Cargo.toml --example zk60_classify
echo $? > $L/b19b-cli-build.exit
[ "$(cat $L/b19b-cli-build.exit)" = "0" ] || finish b19b
mkdir -p $EQ/bin
cp $H/target/release/examples/zk60_classify $EQ/bin/zk60_classify.r19b-candidate
sha256sum $H/target/release/examples/zk60_classify $EQ/bin/zk60_classify.r19b-candidate $R/cli/zk60_classify.r19.release.bin > $L/b19b-cand.sha256
cmp $EQ/bin/zk60_classify.r19b-candidate $R/cli/zk60_classify.r19.release.bin > $L/b19b-vs-r19.cmp 2>&1; echo "cmp exit $?" >> $L/b19b-vs-r19.cmp
finish 0
