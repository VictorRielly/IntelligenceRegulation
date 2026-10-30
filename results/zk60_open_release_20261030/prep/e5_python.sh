#!/usr/bin/env bash
# E5 part 2: re-sync the build copy from staging (keeping hashline/target), then three guarded
# leaf jobs: the Python suite, the zk60_classify example build, the synthetic P1 demo.
# Each writes prep/<name>.{log,done,guard.json}. Launched detached; not itself guarded.
set -u
P=/home/victor/IntelligenceRegulation/results/zk60_open_release_20261030/prep
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
B=/home/victor/ir-public-build
S=/home/victor/ir-public-e5-scratch
CARGO=/home/victor/.cargo/bin/cargo
CLEANPATH=/home/victor/.cargo/bin:/usr/local/bin:/usr/bin:/bin

date -u +"%FT%TZ resync" >> $P/e5_python.queue.log
rsync -a --delete --exclude /hashline/target/ /home/victor/ir-public/ $B/ >> $P/e5_python.queue.log 2>&1
echo "rsync exit $?" >> $P/e5_python.queue.log

date -u +"%FT%TZ py-suite queued" >> $P/e5_python.queue.log
python3 $G run --class cpu --label irpub-e5-py-suite --need-gib 5 --cap-gib 8 \
  --wait-secs 28800 --max-secs 10800 \
  --log $P/e5-py-suite.log --done $P/e5-py-suite.done --result-json $P/e5-py-suite.guard.json \
  -- /usr/bin/env -C $B -u ZK60_REPO -u ZK60_MODELS -u ZK60_ARTIFACTS PATH=$CLEANPATH \
     PYTHONDONTWRITEBYTECODE=1 CARGO_NET_OFFLINE=true CARGO_BUILD_JOBS=2 TMPDIR=$S \
     python3 -m unittest discover -s tests
date -u +"%FT%TZ py-suite exit $?" >> $P/e5_python.queue.log

python3 $G run --class build --label irpub-e5-classify-build --need-gib 3.5 --cap-gib 5 \
  --wait-secs 28800 --max-secs 3600 \
  --log $P/e5-classify-build.log --done $P/e5-classify-build.done --result-json $P/e5-classify-build.guard.json \
  -- /usr/bin/env -C $B/hashline -u ZK60_REPO -u ZK60_MODELS -u ZK60_ARTIFACTS \
     $CARGO build --release --locked --offline -j2 --example zk60_classify
rc=$?
date -u +"%FT%TZ classify-build exit $rc" >> $P/e5_python.queue.log
sha256sum $B/hashline/target/release/examples/zk60_classify >> $P/e5_python.queue.log 2>&1

rm -rf $S/p1-demo
python3 $G run --class cpu --label irpub-e5-p1-demo --need-gib 3 --cap-gib 6 \
  --wait-secs 28800 --max-secs 3600 \
  --log $P/e5-p1-demo.log --done $P/e5-p1-demo.done --result-json $P/e5-p1-demo.guard.json \
  -- /usr/bin/env -C $B -u ZK60_REPO -u ZK60_MODELS -u ZK60_ARTIFACTS PATH=$CLEANPATH \
     CARGO_NET_OFFLINE=true CARGO_BUILD_JOBS=2 \
     python3 scripts/zk60_p1_demo.py --output $S/p1-demo --cargo $CARGO
date -u +"%FT%TZ p1-demo exit $?" >> $P/e5_python.queue.log
echo done > $P/e5_python.done
