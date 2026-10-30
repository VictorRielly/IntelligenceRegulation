#!/usr/bin/env bash
# E5 clean-room native check of the public staging copy (D48 open release).
# Two guarded leaf jobs in sequence; each writes <name>.done (exit code), <name>.log and
# <name>.guard.json under prep/. Launched detached (setsid nohup); not itself guarded.
# Clean room: no ZK60_* / export variables are set; the suite gets only a scratch
# TMPDIR / HL_TIO_FIXTURE_DIR outside any git work tree and the shipped synthetic
# loader fixtures (HL_R13_LOADER_FIXTURES), as the README documents.
set -u
P=/home/victor/IntelligenceRegulation/results/zk60_open_release_20261030/prep
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
B=/home/victor/ir-public-build
S=/home/victor/ir-public-e5-scratch
CARGO=/home/victor/.cargo/bin/cargo

date -u +"%FT%TZ e5-build queued" >> $P/e5_native.queue.log
python3 $G run --class build --label irpub-e5-build --need-gib 3.5 --cap-gib 5 \
  --wait-secs 28800 --max-secs 5400 \
  --log $P/e5-build.log --done $P/e5-build.done --result-json $P/e5-build.guard.json \
  -- /usr/bin/env -C $B/hashline -u ZK60_REPO -u ZK60_MODELS -u ZK60_ARTIFACTS \
     $CARGO build --release --locked --offline -j2
rc=$?
date -u +"%FT%TZ e5-build exit $rc" >> $P/e5_native.queue.log
if [ "$rc" != 0 ]; then echo "$rc" > $P/e5_native.done; exit "$rc"; fi
ls -la $B/hashline/target/release/hashline >> $P/e5_native.queue.log 2>&1
sha256sum $B/hashline/target/release/hashline >> $P/e5_native.queue.log 2>&1

date -u +"%FT%TZ e5-suite queued" >> $P/e5_native.queue.log
python3 $G run --class cpu --label irpub-e5-suite --need-gib 9 --cap-gib 11 \
  --wait-secs 28800 --max-secs 5400 \
  --log $P/e5-suite.log --done $P/e5-suite.done --result-json $P/e5-suite.guard.json \
  -- /usr/bin/env -C $B/hashline -u ZK60_REPO -u ZK60_MODELS -u ZK60_ARTIFACTS \
     TMPDIR=$S HL_TIO_FIXTURE_DIR=$S \
     HL_R13_LOADER_FIXTURES=$B/results/zk60_1b_native_20261017/r13/loader-fixtures \
     $CARGO test --release --locked --offline -j2
rc=$?
date -u +"%FT%TZ e5-suite exit $rc" >> $P/e5_native.queue.log
echo "$rc" > $P/e5_native.done
