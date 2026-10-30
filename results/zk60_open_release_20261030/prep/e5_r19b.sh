#!/usr/bin/env bash
# E5 re-run after the E1 switch to token round 19b / gate v24, in a fresh build copy
# (/home/victor/ir-public-build = a copy of the new staging). Guarded leaf jobs in sequence;
# each writes prep/r19b-<name>.{log,done,guard.json}. Launched detached; not itself guarded.
set -u
P=/home/victor/IntelligenceRegulation/results/zk60_open_release_20261030/prep
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
B=/home/victor/ir-public-build
S=/home/victor/ir-public-e7-scratch
CARGO=/home/victor/.cargo/bin/cargo
CLEANPATH=/home/victor/.cargo/bin:/usr/local/bin:/usr/bin:/bin
Q=$P/r19b_queue.log
step() { date -u +"%FT%TZ $*" >> $Q; }
CLEAN="-u ZK60_REPO -u ZK60_MODELS -u ZK60_ARTIFACTS"

step build queued
python3 $G run --class build --label irpub-r19b-build --need-gib 3.5 --cap-gib 5 --wait-secs 28800 --max-secs 5400 \
  --log $P/r19b-build.log --done $P/r19b-build.done --result-json $P/r19b-build.guard.json \
  -- /usr/bin/env -C $B/hashline $CLEAN $CARGO build --release --locked --offline -j2
rc=$?; step build exit $rc
[ "$rc" = 0 ] || { echo $rc > $P/r19b_queue.done; exit $rc; }
sha256sum $B/hashline/target/release/hashline >> $Q 2>&1

step suite queued
python3 $G run --class cpu --label irpub-r19b-suite --need-gib 11 --cap-gib 12 --wait-secs 28800 --max-secs 5400 \
  --log $P/r19b-suite.log --done $P/r19b-suite.done --result-json $P/r19b-suite.guard.json \
  -- /usr/bin/env -C $B/hashline $CLEAN TMPDIR=$S HL_TIO_FIXTURE_DIR=$S \
     HL_R13_LOADER_FIXTURES=$B/results/zk60_1b_native_20261017/r13/loader-fixtures \
     $CARGO test --release --locked --offline -j2
step suite exit $?

python3 $G run --class build --label irpub-r19b-classify --need-gib 3.5 --cap-gib 5 --wait-secs 28800 --max-secs 3600 \
  --log $P/r19b-classify-build.log --done $P/r19b-classify-build.done --result-json $P/r19b-classify-build.guard.json \
  -- /usr/bin/env -C $B/hashline $CLEAN $CARGO build --release --locked --offline -j2 --example zk60_classify
step classify-build exit $?
sha256sum $B/hashline/target/release/examples/zk60_classify >> $Q 2>&1

step py-suite queued
python3 $G run --class cpu --label irpub-r19b-py-suite --need-gib 5 --cap-gib 8 --wait-secs 28800 --max-secs 10800 \
  --log $P/r19b-py-suite.log --done $P/r19b-py-suite.done --result-json $P/r19b-py-suite.guard.json \
  -- /usr/bin/env -C $B $CLEAN PATH=$CLEANPATH PYTHONDONTWRITEBYTECODE=1 CARGO_NET_OFFLINE=true CARGO_BUILD_JOBS=2 TMPDIR=$S \
     python3 -m unittest discover -s tests -v
step py-suite exit $?

rm -rf $S/p1-demo
python3 $G run --class cpu --label irpub-r19b-p1-demo --need-gib 3 --cap-gib 6 --wait-secs 28800 --max-secs 3600 \
  --log $P/r19b-p1-demo.log --done $P/r19b-p1-demo.done --result-json $P/r19b-p1-demo.guard.json \
  -- /usr/bin/env -C $B $CLEAN PATH=$CLEANPATH CARGO_NET_OFFLINE=true CARGO_BUILD_JOBS=2 \
     python3 scripts/zk60_p1_demo.py --output $S/p1-demo --cargo $CARGO
step p1-demo exit $?
echo done > $P/r19b_queue.done
