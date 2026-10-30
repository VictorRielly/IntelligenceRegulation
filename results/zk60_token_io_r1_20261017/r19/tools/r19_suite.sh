#!/bin/bash
# TOKEN ROUND 19, after r19_chain.sh passed:
#  1. candidate manifest r19A; the FULL suite s24 once (--no-fail-fast, --test-threads=8), guard cpu need 11 / cap 12
#     (the brief: the clean-room run peaked 10.35 GiB RSS / 10.77 cgroup); manifest r19B = r19A
#  2. the zk60_classify release binary from the candidate (build need 2.5 / cap 3.5), copied OUTSIDE the repo to
#     ~/zk60-artifacts/token-io/r19/bin/zk60_classify.r19-candidate (the bytes the checks run; the freeze copies them to
#     cli/), sha256 recorded, compared with r18's 110f0c53… (not byte-equal is expected: production code moved)
# Marker logs/r19_suite.done = 0 or the failing step.
source /home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r19/tools/r19_common.sh
finish() { echo "$1" > $L/r19_suite.done; step "suite end $1"; exit 0; }
EQ=/home/victor/zk60-artifacts/token-io/r19
python3 $F snapshot $T/manifest_r19A.sha256 > $L/r19A-manifest.log 2>&1 || finish manifest-A
turn 11; step s24-suite
$G --class cpu --need-gib 11 --cap-gib 12 --label tio19-s24-suite --wait-secs 21600 --max-secs 3600 --log $L/s24-suite.log --done $L/s24-suite.guard.done --result-json $L/s24-suite.guard.json -- $ENV $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --no-fail-fast -- --test-threads=8
echo $? > $L/s24-suite.exit
python3 $F snapshot $T/manifest_r19B.sha256 > $L/r19B-manifest.log 2>&1
python3 $F compare $T/manifest_r19A.sha256 $T/manifest_r19B.sha256 >> $L/r19B-manifest.log 2>&1
[ "$(cat $L/s24-suite.exit)" = "0" ] || finish s24
grep -q "^changed 0: \[\]" $L/r19B-manifest.log && grep -q "^added 0: \[\]" $L/r19B-manifest.log && grep -q "^removed 0: \[\]" $L/r19B-manifest.log || finish suite-manifest
turn 2.5; step b19-cli-build
$G --class build --need-gib 2.5 --cap-gib 3.5 --label tio19-cli-build --wait-secs 14400 --max-secs 2400 --log $L/b19-cli-build.log --done $L/b19-cli-build.guard.done --result-json $L/b19-cli-build.guard.json -- $CARGO build --release --offline --locked -j2 --manifest-path $H/Cargo.toml --example zk60_classify
echo $? > $L/b19-cli-build.exit
[ "$(cat $L/b19-cli-build.exit)" = "0" ] || finish b19
mkdir -p $EQ/bin
cp $H/target/release/examples/zk60_classify $EQ/bin/zk60_classify.r19-candidate
sha256sum $H/target/release/examples/zk60_classify $EQ/bin/zk60_classify.r19-candidate $R/cli/zk60_classify.r18.release.bin > $L/b19-cand.sha256
cmp $EQ/bin/zk60_classify.r19-candidate $R/cli/zk60_classify.r18.release.bin > $L/b19-vs-r18.cmp 2>&1; echo "cmp exit $?" >> $L/b19-vs-r18.cmp
finish 0
