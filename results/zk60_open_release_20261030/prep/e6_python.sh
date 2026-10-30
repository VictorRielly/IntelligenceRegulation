#!/usr/bin/env bash
# E6: re-sync the clean build copy from staging, then the Python suite as one guarded cpu leaf.
# Writes prep/e6-py-suite.{log,done,guard.json}. Launched detached; not itself guarded.
set -u
P=/home/victor/IntelligenceRegulation/results/zk60_open_release_20261030/prep
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
B=/home/victor/ir-public-build
S=/home/victor/ir-public-e6-scratch
CLEANPATH=/home/victor/.cargo/bin:/usr/local/bin:/usr/bin:/bin
mkdir -p $S
date -u +"%FT%TZ resync" >> $P/e6_python.queue.log
rsync -a --delete /home/victor/ir-public/ $B/ >> $P/e6_python.queue.log 2>&1
echo "rsync exit $?" >> $P/e6_python.queue.log
date -u +"%FT%TZ py-suite queued" >> $P/e6_python.queue.log
python3 $G run --class cpu --label irpub-e6-py-suite --need-gib 5 --cap-gib 8 \
  --wait-secs 28800 --max-secs 10800 \
  --log $P/e6-py-suite.log --done $P/e6-py-suite.done --result-json $P/e6-py-suite.guard.json \
  -- /usr/bin/env -C $B -u ZK60_REPO -u ZK60_MODELS -u ZK60_ARTIFACTS PATH=$CLEANPATH \
     PYTHONDONTWRITEBYTECODE=1 CARGO_NET_OFFLINE=true CARGO_BUILD_JOBS=2 TMPDIR=$S \
     python3 -m unittest discover -s tests -v
date -u +"%FT%TZ py-suite exit $?" >> $P/e6_python.queue.log
echo done > $P/e6_python.done
